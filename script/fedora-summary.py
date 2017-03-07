#!/usr/bin/env python

import sys
import re
import os

object_store = '/repo_data/fedora/fedora36_prod/objectStore/'
ds_store = '/repo_data/fedora/fedora36_prod/datastreamStore/'

class NamespaceInfo:
    def __init__(self):
        self.count = 0
        self.size = 0

class LargestList:
    def __init__(self, number_to_store):
        self.max = number_to_store
        self.data = []
        self.smallest = 0

    def add(self, filename, size):
        if size > self.smallest:
            self.data.append((size, filename))
            self.data.sort(reverse=True)
            if len(self.data) > self.max:
                self.data.pop()
            self.smallest = self.data[-1][0]

# size_to_human assumes the sizes in the following table are increasing
size_name_table = [
    # (bytes, label)
    (1, "B"),
    (2**10, "KiB"),
    (2**20, "MiB"),
    (10**9, "GB"),
    (10**12, "TB")
]

def size_to_human(size):
    if size == 0:
        return "0 bytes"
    for s,n in size_name_table:
        if size < s:
            break
        threshold, label = s, n
    return "%0.2f %s" % (size / float(threshold), label)

class InfoRecorder:
    def __init__(self, largest_count=20):
        # table of namespace: string -> info: NamespaceInfo
        self.seen_table = {}
        self.largest_files = LargestList(largest_count)

    def update_seen_table(self, dirpath, filelist):
        for file in filelist:
            pid_namespace = re.sub(r'.*fedora%2F(.*)%3A.*', r'\1', file.strip())
            x = self.seen_table.get(pid_namespace)
            if not x:
                x = NamespaceInfo()
                self.seen_table[pid_namespace] = x
            x.count += 1
            fqfn = os.path.join(dirpath, file)
            s = os.stat(fqfn)
            x.size += s.st_size
            self.largest_files.add(fqfn, s.st_size)

    def walk_tree(self, root):
        for dirpath, dirs, files in os.walk(root):
            self.update_seen_table(dirpath, files)

def combine_namespace_dicts(left, right):
    "(string -> NamespaceInfo) -> (string -> NamespaceInfo) -> (string -> (NamespaceInfo, NamespaceInfo))"
    result = {}
    for k in iter(left):
        result[k] = (left[k], None)
    for k in iter(right):
        if k in result:
            x,_ = result[k]
            result[k] = (x, right[k])
        else:
            result[k] = (None, right[k])
    return result

def ns_tuple_to_str(t):
    obj, ds = t
    if obj == None:
        obj = NamespaceInfo()
    if ds == None:
        ds = NamespaceInfo()
    total_size = obj.size + ds.size
    return "%d,%d,%d,%d,%s,%d,%s,%d,%s" % (
            obj.count,
            ds.count,
            obj.count + ds.count,
            obj.size,
            size_to_human(obj.size),
            ds.size,
            size_to_human(ds.size),
            total_size,
            size_to_human(total_size))

class TotalCounts:
    def __init__(self):
        self.obj_count = 0
        self.file_count = 0
        self.size = 0
    def update_total_counts(self, t):
        obj, ds = t
        if obj == None:
            obj = NamespaceInfo()
        if ds == None:
            ds = NamespaceInfo()
        self.obj_count += obj.count
        self.file_count += obj.count + ds.count
        self.size += obj.size + ds.size

object_files = InfoRecorder()
object_files.walk_tree(object_store)
ds_files = InfoRecorder()
ds_files.walk_tree(ds_store)

both_files = combine_namespace_dicts(object_files.seen_table, ds_files.seen_table)

output = both_files.keys()
output.sort()
totals = TotalCounts()
print "=== Namespace Summary ==="
print "Namespace,obj_count,ds_count,total_count,obj_size,obj_size_human,ds_size,ds_size_human,total_size,total_size_human"
for k in output:
    print "%s,%s" % (k, ns_tuple_to_str(both_files[k]))
    totals.update_total_counts(both_files[k])

if "-v" in sys.argv:
    print "Total objects %d" % totals.obj_count
    print "Total files %d" % totals.file_count
    print "Total size %d (%s)" % (totals.size, size_to_human(totals.size))
    print "=== 20 Largest Object files ==="
    for size,file in object_files.largest_files.data:
        print "%s %s" % (size_to_human(size),file)
    print "=== 20 Largest Datastream files ==="
    for size,file in ds_files.largest_files.data:
        print "%s %s" % (size_to_human(size),file)
