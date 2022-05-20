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

ActiveRecord::Schema.define(version: 20180725184352) do

  create_table "curate_storage_details", force: :cascade do |t|
    t.string   "storage_type", limit: 255, null: false
    t.integer  "object_count", limit: 4,   null: false
    t.integer  "object_bytes", limit: 8,   null: false
    t.date     "harvest_date",             null: false
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "curate_storage_details", ["harvest_date"], name: "index_curate_storage_details_on_harvest_date"
  add_index "curate_storage_details", ["object_count"], name: "index_curate_storage_details_on_object_count"
  add_index "curate_storage_details", ["storage_type"], name: "index_curate_storage_details_on_storage_type"

  create_table "fedora_access_events", force: :cascade do |t|
    t.string   "event",      limit: 255, null: false
    t.string   "pid",        limit: 255, null: false
    t.string   "location",   limit: 255, null: false
    t.datetime "event_time",             null: false
    t.string   "agent",      limit: 255, null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "fedora_access_events", ["agent"], name: "index_fedora_access_events_on_agent"
  add_index "fedora_access_events", ["event"], name: "index_fedora_access_events_on_event"
  add_index "fedora_access_events", ["event_time"], name: "index_fedora_access_events_on_event_time"
  add_index "fedora_access_events", ["location"], name: "index_fedora_access_events_on_location"
  add_index "fedora_access_events", ["pid"], name: "index_fedora_access_events_on_pid"

  create_table "fedora_object_aggregation_keys", force: :cascade do |t|
    t.integer  "fedora_object_id", limit: 4,                null: false
    t.string   "aggregation_key",  limit: 255,              null: false
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.string   "predicate_name",   limit: 255, default: ""
  end

  add_index "fedora_object_aggregation_keys", ["aggregation_key"], name: "index_fedora_object_aggregation_keys_on_aggregation_key"
  add_index "fedora_object_aggregation_keys", ["fedora_object_id"], name: "index_fedora_object_aggregation_keys_on_fedora_object_id"
  add_index "fedora_object_aggregation_keys", ["predicate_name"], name: "index_fedora_object_aggregation_keys_on_predicate_name"

  create_table "fedora_object_edit_groups", force: :cascade do |t|
    t.integer  "fedora_object_id", limit: 4,   null: false
    t.string   "edit_group_pid",   limit: 255, null: false
    t.string   "edit_group_name",  limit: 255, null: false
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  add_index "fedora_object_edit_groups", ["edit_group_name"], name: "index_fedora_object_edit_groups_on_edit_group_name"
  add_index "fedora_object_edit_groups", ["edit_group_pid"], name: "index_fedora_object_edit_groups_on_edit_group_pid"
  add_index "fedora_object_edit_groups", ["fedora_object_id"], name: "index_fedora_object_edit_groups_on_fedora_object_id"

  create_table "fedora_objects", force: :cascade do |t|
    t.string   "pid",               limit: 255,              null: false
    t.string   "af_model",          limit: 255,              null: false
    t.string   "resource_type",     limit: 255,              null: false
    t.string   "mimetype",          limit: 255,              null: false
    t.integer  "bytes",             limit: 8,                null: false
    t.string   "parent_pid",        limit: 255,              null: false
    t.datetime "obj_ingest_date",                            null: false
    t.datetime "obj_modified_date",                          null: false
    t.string   "access_rights",     limit: 255,              null: false
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
    t.string   "title",             limit: 255, default: ""
    t.string   "parent_type",       limit: 255, default: ""
  end

  add_index "fedora_objects", ["access_rights"], name: "index_fedora_objects_on_access_rights"
  add_index "fedora_objects", ["af_model"], name: "index_fedora_objects_on_af_model"
  add_index "fedora_objects", ["mimetype"], name: "index_fedora_objects_on_mimetype"
  add_index "fedora_objects", ["obj_ingest_date"], name: "index_fedora_objects_on_obj_ingest_date"
  add_index "fedora_objects", ["obj_modified_date"], name: "index_fedora_objects_on_obj_modified_date"
  add_index "fedora_objects", ["parent_pid"], name: "index_fedora_objects_on_parent_pid"
  add_index "fedora_objects", ["parent_type"], name: "index_fedora_objects_on_parent_type"
  add_index "fedora_objects", ["pid"], name: "index_fedora_objects_on_pid"
  add_index "fedora_objects", ["resource_type"], name: "index_fedora_objects_on_resource_type"
  add_index "fedora_objects", ["title"], name: "index_fedora_objects_on_title"

  create_table "periodic_metric_reports", force: :cascade do |t|
    t.date     "start_date",                    null: false
    t.date     "end_date",                      null: false
    t.text     "content",    limit: 4294967295
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  add_index "periodic_metric_reports", ["end_date"], name: "index_periodic_metric_reports_on_end_date"
  add_index "periodic_metric_reports", ["start_date"], name: "index_periodic_metric_reports_on_start_date"

end
