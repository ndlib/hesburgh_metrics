require 'rails_helper'

RSpec.describe FedoraObjectHarvester do
  context '#harvest' do
    let(:harvester) { described_class.new }
    subject { harvester.harvest }
    around do |spec|
      VCR.use_cassette("single_item_search") do
        spec.call
      end
    end
    it 'will transform returned objects from a search into FedoraObjects for reporting', functional: true do
      expect do
        expect do
          subject
        end.to change { FedoraObject.count }.by(1)
      end.to change { FedoraObjectAggregationKey.count }.by(2)
    end
    it 'will report to Airbrake any exceptions encountered' do
      allow(harvester).to receive(:single_item_harvest).and_raise(RuntimeError)
      expect(Airbrake).to receive(:notify_sync).and_call_original
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
    VCR.use_cassette("single_item_search") do
      the_doc = harvester.repo.search('pid~und:*').first
    end
    the_doc
  end
  let(:harvester) { FedoraObjectHarvester.new }
  let(:single_item) { described_class.new(doc, harvester) }

  context '#parent_pid' do
    subject { single_item.send(:parent_pid) }
    context 'for non-GenericFile content' do
      before { allow(single_item).to receive(:af_model).and_return('Book') }
      it { is_expected.to eq(single_item.pid) }
    end
  end

  context '#parse_xml_relsext' do
    subject { single_item.send(:parse_xml_relsext, content, 'isPartOf') }
    context 'for parse_xml_relsext for parent pid' do
      let (:content) { %(<?xml version='1.0' encoding='utf-8' ?>
      <rdf:RDF xmlns:ns0='http://projecthydra.org/ns/relations#' xmlns:ns1='info:fedora/fedora-system:def/model#' xmlns:ns2='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
        <rdf:Description rdf:about='info:fedora/und:02870v85054'>
          <ns0:hasEditor rdf:resource='info:fedora/und:ks65h991r5x' />
          <ns0:hasEditorGroup rdf:resource='info:fedora/und:ms35t724s3j' />
          <ns0:hasViewerGroup rdf:resource='info:fedora/und:7m01bk14722' />
          <ns1:hasModel rdf:resource='info:fedora/afmodel:GenericFile' />
          <ns2:isPartOf rdf:resource='info:fedora/und:zs25x636043' />
        </rdf:Description>
      </rdf:RDF>) }
      it { is_expected.to eq('und:zs25x636043') }
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

  context "#parse_triples" do
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
    end
  end
end
