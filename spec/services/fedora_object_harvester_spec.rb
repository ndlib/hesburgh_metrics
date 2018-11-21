require 'rails_helper'

RSpec.describe FedoraObjectHarvester do
  VCR_CASSETTE_NAME = 'test_cassette'
  context "rebuilding #{VCR_CASSETTE_NAME}" do
    # The following steps to rebuild:
    # 1) Get the Fedora production URL, User, and Password from the secrets, you will pass these as environment variables (see line 10)
    # 2) Change the `xit` to `it` (when you are done, change it back)
    # 3) Run the following command, replacing the <from-secrets> with the correct values
    #  (note the ./spec/services/fedora_object_harvester_spec.rb:12 means to run the `it` block on line 11)
    #     prod_fedora_user=<from-secrets> prod_fedora_password=<from-secrets> prod_fedora_url=<from-secrets> bundle exec rspec ./spec/services/fedora_object_harvester_spec.rb:12
    xit 'can be done!' do
      repository = Rubydora.connect(url: Figaro.env.prod_fedora_url!, user: Figaro.env.prod_fedora_user!, password: Figaro.env.prod_fedora_password!)
      pid_from_cassette = 'und:ms35t724s3j'
      VCR.use_cassette(VCR_CASSETTE_NAME, record: :all) do
        described_class.new(repository).harvest("pid~#{pid_from_cassette}")
      end

      path_to_cassette = File.join(VCR.configuration.cassette_library_dir, 'test_cassette.yml')
      cassette_contents = File.read(path_to_cassette)
      File.open(path_to_cassette, 'w+') do |file|
        file.puts cassette_contents.gsub(Figaro.env.prod_fedora_url!, Figaro.env.fedora_url!)
      end
    end
  end

  context '#harvest' do
    let(:harvester) { described_class.new }
    subject { harvester.harvest }
    around do |spec|
      VCR.use_cassette(VCR_CASSETTE_NAME) do
        spec.call
      end
    end
    it 'will transform returned objects from a search into FedoraObjects for reporting', functional: true do
      expect do
        expect do
          expect do
              subject
          end.to change { FedoraObject.count }.by(1)
        end.to change { FedoraObjectAggregationKey.count }.by(2)
      end.to change { FedoraObjectEditGroup.count }.by(1)
    end
    it 'will report to Sentry any exceptions encountered' do
      allow(harvester).to receive(:single_item_harvest).and_raise(RuntimeError)
      expect(Raven).to receive(:capture_exception).and_call_original.exactly(1).times
      subject
    end
  end

  context '#repo' do
    subject { described_class.new.repo }
    it { is_expected.to respond_to(:search) }
  end
end

RSpec.describe FedoraObjectHarvester::SingleItem do
  let(:doc) do
    # We need to stub out a "real" document from Rubydora, and this is our best
    # option (so says Jeremy).
    the_doc = nil
    VCR.use_cassette(VCR_CASSETTE_NAME) do
      the_doc = harvester.repo.search('pid~und:*').first
    end
    the_doc
  end
  let(:harvester) { FedoraObjectHarvester.new }
  let(:single_item) { described_class.new(doc, harvester) }

  context '#get_and_add_or_delete_aggregation_keys' do
    subject { single_item.send(:get_and_add_or_delete_aggregation_keys, fedora_object, 'test') }
    let (:fedora_object) { FedoraObject.create(pid: 'some_pid', af_model: 'a model', resource_type: 'a resource type',
                                               obj_ingest_date: '2015-12-12', obj_modified_date: '2015-12-12',
                                               mimetype: 'a mime type', bytes: 100, access_rights: 'rights',
                                               parent_pid: 'some_pid')   }
    let(:fedora_aggregation_key) { FedoraObjectAggregationKey.new(aggregation_key:'Random Data') }
    let(:stream) do
      %(<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/title> "Collection with long description" .\n
      <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/description> "The most recent versions of V-Dem data" .\n
      <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/dateSubmitted> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .\n
      <info:fedora/und:00000001s4s> <http://purl.org/dc/terms/language> "English" .\n
      <info:fedora/und:00000001s4s> <http://purl.org/dc/terms/test> "My Test Data" .\n
      <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/modified> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .)
    end
    let(:doc) { double('DigitalObject',
                       datastreams: { 'descMetadata' => double(content: stream) },
                       pid: 'und:mp48sb41h1s',
                       profile: {}) }
    let(:single_item) { described_class.new(doc, harvester) }
    it 'to create aggregation key and value' do
      allow(fedora_object).to receive_message_chain("fedora_object_aggregation_keys.where") { [] }
      allow(FedoraObjectAggregationKey).to receive(:first_or_initialize).and_call_original
      expect{ subject }.to change { FedoraObjectAggregationKey.count }.by(1)
    end
    it 'to destroy FedoraObjectAggregationKey if not present as metadata' do
      allow(fedora_object).to receive_message_chain("fedora_object_aggregation_keys.where") { [fedora_aggregation_key] }
      FedoraObjectAggregationKey.any_instance.stub(:destroy).and_call_original
      subject
      expect(fedora_aggregation_key).to have_received(:destroy)
    end
  end

  context '#get_and_add_or_delete_edit_groups' do
    subject { single_item.send(:get_and_add_or_delete_edit_groups, fedora_object) }
    let(:fedora_object) { FedoraObject.create(pid: 'some_pid',
                                              af_model: 'a model',
                                              resource_type: 'a resource type',
                                              obj_ingest_date: '2015-12-12',
                                              obj_modified_date: '2015-12-12',
                                              mimetype: 'a mime type',
                                              bytes: 100,
                                              access_rights: 'rights',
                                              parent_pid: 'some_pid') }
    let(:doc) do
      double('DigitalObject', pid: 'und:mp48sb41h1s', profile: {}, datastreams: { 'rightsMetadata' => double(content: rights_stream) } )
    end
    let(:rights_stream) do
      %(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1" version="0.1"><copyright><human type="title"/><human type="description"/><machine type="uri"/></copyright><access type="discover"><human/><machine/></access><access type="read"><human/><machine><group>public</group></machine></access><access type="edit"><human/><machine><group>und:ms35t724s3j</group></machine></access><embargo><human/><machine><date>2030-06-01</date></machine></embargo></rightsMetadata>)
    end
    let(:single_item) { described_class.new(doc, harvester) }
    let(:fedora_edit_group) { FedoraObjectEditGroup.new(fedora_object: fedora_object, edit_group_pid:'xxxxxxxx', edit_group_name: 'Some Group' ) }
    around do |spec|
      VCR.use_cassette(VCR_CASSETTE_NAME) do
        spec.call
      end
    end
    it 'to create FedoraObjectEditGroup' do
      allow(FedoraObjectEditGroup).to receive(:first_or_initialize).and_call_original
      expect{ subject }.to change { FedoraObjectEditGroup.count }.by(1)
    end
    it 'to destroy FedoraObjectEditGroup if not present as metadata' do
      allow(fedora_object).to receive_message_chain("fedora_object_edit_groups") { [fedora_edit_group] }
      FedoraObjectEditGroup.any_instance.stub(:destroy).and_call_original
      subject
      expect(fedora_edit_group).to have_received(:destroy)
    end
  end

  context '#parent_pid' do
    context 'for non-GenericFile content' do
      subject { single_item.send(:parent_pid) }
      before { allow(single_item).to receive(:af_model).and_return('Book') }
      it { is_expected.to eq(single_item.pid) }
    end
  end

  context '#parent_type' do
    subject { single_item.send(:parent_type) }
    context 'for non-GenericFile content' do
      before { allow(single_item).to receive(:af_model).and_return('Book') }
      it { is_expected.to eq('Book') }
    end
    context 'existing object in database' do
      let(:fedora_object) { double(pid: 'zs25x636043', af_model: "Dataset") }
      before { allow(single_item).to receive(:parent_pid).and_return('zs25x636043') }
      it 'Gets af_model from database object' do
        expect(FedoraObject).to receive(:find_by).and_return(fedora_object)
        expect(subject).to eq(fedora_object.af_model)
      end
    end
  end

  context '#title' do
    subject { single_item.send(:title) }
    context 'for non-GenericFile content' do
      let(:stream) { %(<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/title> "Collection with long description" .\n<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/description> "The most recent versions of V-Dem data" .\n<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/dateSubmitted> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .\n<info:fedora/und:00000001s4s> <http://purl.org/dc/terms/language> "English" .\n<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/modified> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .) }
      let(:doc) { double('DigitalObject', datastreams: { 'descMetadata' => double(content: stream) }, pid: 'und:mp48sb41h1s', profile: {}) }
      before { allow(single_item).to receive(:af_model).and_return('Collection') }
      it { is_expected.to eq('Collection with long description') }
    end
  end

  context '#access_rights' do
    subject { single_item.send(:access_rights) }
    context 'when no rightmetadata present' do
      let (:doc) { double('DigitalObject', datastreams: { 'descMetadata' => double(content: '') }, pid: 'und:mp48sb41h1s', profile: {}) }
      it { is_expected.to eq('private') }
    end
    context 'When rightsMetadata available' do
      let (:rights) { %(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1" version="0.1"><copyright><human type="title"/><human type="description"/><machine type="uri"/></copyright><access type="discover"><human/><machine/></access><access type="read"><human/><machine><group>public</group></machine></access><access type="edit"><human/><machine><person>msisk1</person></machine></access><embargo><human/><machine/></embargo></rightsMetadata>) }
      let (:doc) { double('DigitalObject', datastreams: { 'descMetadata' => double(content: ''),
                                                          'rightsMetadata' => double(content: rights) },
                          pid: 'und:mp48sb41h1s', profile: {}) }
      it { is_expected.to eq('public') }
    end
  end

  context '#resource_type' do
    subject { single_item.send(:resource_type) }
    before { allow(single_item).to receive(:af_model).and_return('af_model') }
    context 'without DescMetadata' do
      let(:doc) { double('DigitalObject', datastreams: { }, pid: 'und:mp48sb41h1s', profile: {}) }
      it { is_expected.to eq('af_model') }
    end

    context 'with DescMetadata' do
      let (:stream) do
        %(<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/title> "Collection with long description" .\n
        <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/description> "The most recent versions of V-Dem data" .\n
        <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/dateSubmitted> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .\n
        <info:fedora/und:00000001s4s> <http://purl.org/dc/terms/language> "English" .\n
        <info:fedora/und:00000001s4s> <http://purl.org/dc/terms/type> "some type" .\n
        <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/modified> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .)
      end
      let(:doc) { double('DigitalObject', datastreams: { 'descMetadata' => double(content: stream) }, pid: 'und:mp48sb41h1s', profile: {}) }
      it { is_expected.to eq('some type') }
    end

    context 'with DescMetadata without type' do
      let (:stream) do
        %(<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/title> "Collection with long description" .\n
        <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/description> "The most recent versions of V-Dem data" .\n
        <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/dateSubmitted> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .\n
        <info:fedora/und:00000001s4s> <http://purl.org/dc/terms/language> "English" .\n
        <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/modified> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .)
      end
      let(:doc) { double('DigitalObject', datastreams: { 'descMetadata' => double(content: stream) }, pid: 'und:mp48sb41h1s', profile: {}) }
      it { is_expected.to eq('af_model') }
    end
  end

  context '#mimetype' do
    subject { single_item.send(:mimetype) }
    context 'for non-GenericFile' do
      let(:doc) { double('DigitalObject', datastreams: { 'descMetadata' => double(content: "descMetadataContent") }, pid: 'und:mp48sb41h1s', profile: {}) }
      it { is_expected.to be_empty }
    end
    context 'for GenericFile' do
      let(:doc) { double('DigitalObject', datastreams: { 'descMetadata' => double(content: "descMetadataContent"), 'content' => double(label:'fileName', mimeType: "mimetype")}, pid: 'und:mp48sb41h1s', profile: {}) }
      it { is_expected.to eq('mimetype') }
    end
  end

  context '#bytes' do
    subject { single_item.send(:bytes) }
    context 'for non-GenericFile' do
      let(:doc) { double('DigitalObject', datastreams: { 'descMetadata' => double(content: "descMetadataContent") }, pid: 'und:mp48sb41h1s', profile: {}) }
      it { is_expected.to eq(0) }
    end
    context 'for GenericFile' do
      let(:doc) { double('DigitalObject', datastreams: { 'descMetadata' => double(content: "descMetadataContent"), 'content' => double(label:'fileName', size: "100")}, pid: 'und:mp48sb41h1s', profile: {}) }
      it { is_expected.to eq('100') }
    end
  end

  context '#fedora_changed?' do
    subject { single_item.send(:fedora_changed?, content) }
    let (:content) { FedoraObject.new }
    context 'for new record' do
      it { is_expected.to eq(false) }
    end
  end

  context 'for GenericFile content' do
    let (:rels_ext) do
      %(<?xml version='1.0' encoding='utf-8' ?>
        <rdf:RDF xmlns:ns0='http://projecthydra.org/ns/relations#' xmlns:ns1='info:fedora/fedora-system:def/model#' xmlns:ns2='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
          <rdf:Description rdf:about='info:fedora/und:02870v85054'>
            <ns0:hasEditor rdf:resource='info:fedora/und:ks65h991r5x' />
            <ns0:hasEditorGroup rdf:resource='info:fedora/und:ms35t724s3j' />
            <ns0:hasViewerGroup rdf:resource='info:fedora/und:7m01bk14722' />
            <ns1:hasModel rdf:resource='info:fedora/afmodel:GenericFile' />
            <ns2:isPartOf rdf:resource='info:fedora/und:zs25x636043' />
          </rdf:Description>
        </rdf:RDF>)
    end
    let(:descMetdata) do
      %(<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/title> "Collection with long description" .\n
        <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/description> "The most recent versions of V-Dem data" .\n
        <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/dateSubmitted> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .\n
        <info:fedora/und:00000001s4s> <http://purl.org/dc/terms/language> "English" .\n
        <info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/modified> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .)
    end
    let(:gf_doc) { double('DigitalObject',
                   datastreams: {'descMetdata' => double(descMetdata: descMetdata),
                                 'RELS-EXT' => double(content: rels_ext),
                                 'content' => double(label:'fileName') },
                   pid: 'und:mp48sb41h1s', profile: {}) }
    let(:single_gf_item) { described_class.new(gf_doc, harvester) }
    before :each do
      allow(single_gf_item).to receive(:af_model).and_return('GenericFile')
    end
    context '#parent_pid' do
      subject { single_gf_item.send(:parent_pid) }
      it { is_expected.to eq('zs25x636043') }
    end

    context '#parent_type' do
      subject { single_gf_item.send(:parent_type) }
      around do |spec|
        VCR.use_cassette(VCR_CASSETTE_NAME) do
          spec.call
        end
      end
      before do
        allow(FedoraObject).to receive(:find_by).and_return(nil)
      end
      it { is_expected.to eq('Dataset') }
    end

    context '#title' do
      subject { single_gf_item.send(:title) }
      it { is_expected.to eq('fileName') }
    end
  end

  context '#parse_xml_relsext' do
    subject { single_item.send(:parse_xml_relsext, content, 'isPartOf') }
    context 'for parse_xml_relsext for parent pid' do
      let (:content) do
        %(<?xml version='1.0' encoding='utf-8' ?>
      <rdf:RDF xmlns:ns0='http://projecthydra.org/ns/relations#' xmlns:ns1='info:fedora/fedora-system:def/model#' xmlns:ns2='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
        <rdf:Description rdf:about='info:fedora/und:02870v85054'>
          <ns0:hasEditor rdf:resource='info:fedora/und:ks65h991r5x' />
          <ns0:hasEditorGroup rdf:resource='info:fedora/und:ms35t724s3j' />
          <ns0:hasViewerGroup rdf:resource='info:fedora/und:7m01bk14722' />
          <ns1:hasModel rdf:resource='info:fedora/afmodel:GenericFile' />
          <ns2:isPartOf rdf:resource='info:fedora/und:zs25x636043' />
        </rdf:Description>
      </rdf:RDF>)
      end
      it { is_expected.to eq('und:zs25x636043') }
    end
  end

  context '#parse_edit_groups' do
    subject { single_item.send(:parse_edit_groups, content) }
    context 'for no edit groups' do
      let (:content) { %(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1" version="0.1"><copyright><human type="title"/><human type="description"/><machine type="uri"/></copyright><access type="discover"><human/><machine/></access><access type="read"><human/><machine><group>registered</group></machine></access><access type="edit"><human/><machine><person>msisk1</person></machine></access><embargo><human/><machine/></embargo></rightsMetadata>) }
      it { is_expected.to eq([]) }
    end
    context 'for 1 group' do
      let (:content) { %(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1" version="0.1"><copyright><human type="title"/><human type="description"/><machine type="uri"/></copyright><access type="discover"><human/><machine/></access><access type="read"><human/><machine><group>registered</group></machine></access><access type="edit"><human/><machine><person>msisk1</person><group>und:ms35t724s3j</group></machine></access><embargo><human/><machine/></embargo></rightsMetadata>) }
      it { is_expected.to eq(['und:ms35t724s3j']) }
    end
    context 'for 3 groups' do
      let (:content) { %(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1" version="0.1"><copyright><human type="title"/><human type="description"/><machine type="uri"/></copyright><access type="discover"><human/><machine/></access><access type="read"><human/><machine><group>registered</group></machine></access><access type="edit"><human/><machine><person>msisk1</person><group>und:1111111</group><group>und:2222222</group><group>und:3333333</group></machine></access><embargo><human/><machine/></embargo></rightsMetadata>) }
      it { is_expected.to eq(['und:1111111', 'und:2222222', 'und:3333333']) }
    end
  end

  context '#parse_xml_rights' do
    subject { single_item.send(:parse_xml_rights, content) }
    context 'for public with embargo' do
      let (:content) { %(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1" version="0.1"><copyright><human type="title"/><human type="description"/><machine type="uri"/></copyright><access type="discover"><human/><machine/></access><access type="read"><human/><machine><group>public</group></machine></access><access type="edit"><human/><machine><person>msisk1</person></machine></access><embargo><human/><machine><date>2030-06-01</date></machine></embargo></rightsMetadata>) }
      it { is_expected.to eq('public (embargo)') }
    end
    context 'for local' do
      let (:content) { %(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1" version="0.1"><copyright><human type="title"/><human type="description"/><machine type="uri"/></copyright><access type="discover"><human/><machine/></access><access type="read"><human/><machine><group>registered</group></machine></access><access type="edit"><human/><machine><person>msisk1</person></machine></access><embargo><human/><machine/></embargo></rightsMetadata>) }
      subject { single_item.send(:parse_xml_rights, content) }
      it { is_expected.to eq('local') }
    end
    context 'for no defined rights value' do
      let (:content) { %(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1" version="0.1"><copyright><human type="title"/><human type="description"/><machine type="uri"/></copyright><access type="discover"><human/><machine/></access><access type="read"><human/><machine><group>something</group></machine></access><access type="edit"><human/><machine><person>msisk1</person></machine></access><embargo><human/><machine/></embargo></rightsMetadata>) }
      subject { single_item.send(:parse_xml_rights, content) }
      it { is_expected.to eq('private') }
    end
    context 'for explicit private rights' do
      let (:content) { %(<rightsMetadata xmlns="http://hydra-collab.stanford.edu/schemas/rightsMetadata/v1" version="0.1"><copyright><human type="title"/><human type="description"/><machine type="uri"/></copyright><access type="discover"><human/><machine><person>private</person></machine></access><access type="read"><human/><machine><person>private</person></machine></access><access type="edit"><human/><machine><person>msisk1</person></machine></access><embargo><human/><machine/></embargo></rightsMetadata>) }
      subject { single_item.send(:parse_xml_rights, content) }
      it { is_expected.to eq('private') }
    end
  end

  context '#parse_triples' do
    context 'parse some data normally' do
      let (:content) { %(<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/title> "Collection with long description" .\n<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/description> "The most recent versions of V-Dem data" .\n<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/dateSubmitted> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .\n<info:fedora/und:00000001s4s> <http://purl.org/dc/terms/language> "English" .\n<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/modified> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .) }
      subject { single_item.send(:parse_triples, content, 'language') }
      it { is_expected.to eq(['English']) }
    end
    context 'will handle reader errors Reader::Error on one statement' do
      let (:content) { %(<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/title> "Collection with long description" .\n<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/description> "The most recent versions of V-Dem data" .\n<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/dateSubmitted> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .\n<info:fedora/und:00000001s4s> <http://purl.org/dc/terms/language> "English" .\n<info:fedora/und:mp48sb41h1s> <http://purl.org/dc/terms/modified> "2014-12-19Z"^^<http://www.w3.org/2001/XMLSchema#date> .) }
      subject { single_item.send(:parse_triples, content, 'language') }
      it 'will record an exception on the harvester' do
        allow_any_instance_of(::RDF::NTriples::Reader).to receive(:each_statement).and_raise(RDF::ReaderError.new(''))
        expect { subject }.to change { harvester.exceptions.count }.by(1)
      end
      it { is_expected.to eq(['English']) }
    end
  end
end
