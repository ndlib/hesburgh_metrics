# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160429182131) do

  create_table "fedora_object_aggregation_keys", force: :cascade do |t|
    t.integer  "fedora_object_id", null: false
    t.string   "aggregation_key",  null: false
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  add_index "fedora_object_aggregation_keys", ["aggregation_key"], name: "index_fedora_object_aggregation_keys_on_aggregation_key"
  add_index "fedora_object_aggregation_keys", ["fedora_object_id"], name: "index_fedora_object_aggregation_keys_on_fedora_object_id"

  create_table "fedora_objects", force: :cascade do |t|
    t.string   "pid",               null: false
    t.string   "af_model",          null: false
    t.string   "resource_type",     null: false
    t.string   "mimetype",          null: false
    t.integer  "bytes",             null: false
    t.string   "parent_pid",        null: false
    t.datetime "obj_ingest_date",   null: false
    t.datetime "obj_modified_date", null: false
    t.string   "access_rights",     null: false
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "fedora_objects", ["access_rights"], name: "index_fedora_objects_on_access_rights"
  add_index "fedora_objects", ["af_model"], name: "index_fedora_objects_on_af_model"
  add_index "fedora_objects", ["mimetype"], name: "index_fedora_objects_on_mimetype"
  add_index "fedora_objects", ["obj_ingest_date"], name: "index_fedora_objects_on_obj_ingest_date"
  add_index "fedora_objects", ["obj_modified_date"], name: "index_fedora_objects_on_obj_modified_date"
  add_index "fedora_objects", ["parent_pid"], name: "index_fedora_objects_on_parent_pid"
  add_index "fedora_objects", ["pid"], name: "index_fedora_objects_on_pid"
  add_index "fedora_objects", ["resource_type"], name: "index_fedora_objects_on_resource_type"

end
