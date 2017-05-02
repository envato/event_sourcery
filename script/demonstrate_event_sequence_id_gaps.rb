# Demonstrates that sequence IDs may not be inserted linearly with concurrent
# writers.
#
# This script writes events in parallel from a number of forked processes,
# writing events in a continious loop until the program is interrupted.
# The parent process detects gaps in sequence IDs by selecting the last 2
# events based on sequence ID. A gap is detected when the 2 IDs returned from
# that query aren't sequential. The script will proceed to execute 2 subsequent
# queries to see if they show up in the time it takes to complete those before
# moving on.
#
# An easier way to demonstrate this is by using 2 psql consoles:
#
# - Simulate a transaction taking a long time to commit:
#   ```
#   begin;
#   insert into events (..) values (..);
#   ```
# - Then, in another console:
#   ```
#   insert into events (..) values (..);
#   select * from events;
#   ```
#
# The result is that event sequence ID 2 is visible, but only when the first
# transaction commits is event sequence ID 1 visible.
#
# Why does this happen?
#
# Sequences in Postgres (and most other DBs) are not transactional, changes
# to the sequence are visible to other transactions immediately. Also, Inserts
# from the forked writers are executed in parallel by postgres.
#
# The process of inserting into a table that has a sequence or serial column is
# to first get the next sequence ID (changing global state), then perform the
# insert statement and later commit. In between these 2 steps the sequence ID
# is taken but not visible in the table until the insert statement is
# committed. Gaps in sequence IDs occur when a process takes a sequence ID and
# commits it while another process is in between those 2 steps.
#
# This means another transaction could have taken the next sequence
# ID and committed before that one commits, resulting in a gap in sequence ID's
# when reading.
#
# Why is this a problem?
#
# Consumers of events use the sequence ID to keep track of where they're up to
# in the events table. If a projector processes an event with sequence ID n, it
# assumes that the next event it needs to process will have a sequence ID > n.
# This approach doesn't work when sequence IDs are inserted non-linearly, event
# stream processors would skip events under concurrent writes to the event
# store as demonstrated with this script.
#
# How does EventSourcery deal with this?
#
# EventSourcery uses an transaction level advisory lock to synchronise inserts
# to the events table within the writeEvents function. Alternatives:
#
# - Write events from 1 process only (serialize at the application level)
# - Detect gaps when reading events and allow time for in-flight transactions
# (the gaps) to commit.
# - Built in eventual consistency. Selects would be restricted to events older
# than 500ms-1s or the transaction timeout to give enough time for in-flight
# transactions to commit.
# - Only query events when catching up, after that rely on events to be
# delivered through the pub/sub mechanism. Given events would be received out
# of order under concurrent writes there's potential for processors to process
# a given event twice if they shutdown after processing a sequence that was
# part of a gap.
#
# Usage:
#
# ❯ bundle exec ruby script/demonstrate_event_sequence_id_gaps.rb
# 89847: starting to write events89846: starting to write events

# 89848: starting to write events
# 89849: starting to write events
# 89850: starting to write events
# GAP: 1 missing sequence IDs. 78 != 76 + 1. Missing events showed up after 1 subsequent query. IDs: [77]
# GAP: 1 missing sequence IDs. 168 != 166 + 1. Missing events showed up after 1 subsequent query. IDs: [167]
# GAP: 1 missing sequence IDs. 274 != 272 + 1. Missing events showed up after 1 subsequent query. IDs: [273]
# GAP: 1 missing sequence IDs. 341 != 339 + 1. Missing events showed up after 1 subsequent query. IDs: [340]
# GAP: 1 missing sequence IDs. 461 != 459 + 1. Missing events showed up after 1 subsequent query. IDs: [460]
# GAP: 1 missing sequence IDs. 493 != 491 + 1. Missing events showed up after 1 subsequent query. IDs: [492]
# GAP: 2 missing sequence IDs. 621 != 618 + 1. Missing events showed up after 1 subsequent query. IDs: [619, 620]

require 'sequel'
require 'securerandom'
require 'event_sourcery'

def connect
  pg_uri = ENV.fetch('BOXEN_POSTGRESQL_URL') { 'postgres://127.0.0.1:5432/' }.dup
  pg_uri << 'event_sourcery_test'
  Sequel.connect(pg_uri)
end

EventSourcery.logger.level = :info

def new_event
  EventSourcery::Event.new(type: :item_added,
                           aggregate_id: SecureRandom.uuid,
                           body: { 'something' => 'simple' })
end

def create_events_schema(db)
  db.execute 'drop table if exists events'
  db.execute 'drop table if exists aggregates'
  EventSourcery::Postgres::Schema.create_event_store(db: db, use_optimistic_concurrency: true)
end

db = connect
create_events_schema(db)
db.disconnect
sleep 0.3

NUM_WRITER_PROCESSES = 5
NUM_WRITER_PROCESSES.times do
  fork do |pid|
    stop = false
    Signal.trap(:INT) { stop = true }
    db = connect
    # when lock_table is set to true an advisory lock is used to synchronise
    # inserts and no gaps are detected
    event_store = EventSourcery::Postgres::EventStoreWithOptimisticConcurrency.new(db, lock_table: false)
    puts "#{Process.pid}: starting to write events"
    until stop
      event_store.sink(new_event)
    end
  end
end

stop = false
Signal.trap(:INT) { stop = true }

def wait_for_missing_ids(db, first_sequence, last_sequence, attempt: 1)
  missing_ids = db[:events].where("id > ? AND id < ?", first_sequence, last_sequence).order(:id).map {|e| e[:id] }
  expected_missing_ids = (first_sequence+1)..(last_sequence-1)
  if missing_ids == expected_missing_ids.to_a
    print "Missing events showed up after #{attempt} subsequent query. IDs: #{missing_ids}"
  else
    if attempt < 2
      wait_for_missing_ids(db, first_sequence, last_sequence, attempt: attempt + 1)
    else
      print "Missing events didn't show up after #{attempt} subsequent queries"
    end
  end
end

until stop

  # query for the last 2 sequences in the events table
  first_sequence, last_sequence = *db[:events].
    order(Sequel.desc(:id)).
    select(:id).
    limit(2).
    map { |e| e[:id] }.
    reverse

  next if first_sequence.nil? || last_sequence.nil?

  if last_sequence != first_sequence + 1
    num_missing = last_sequence - first_sequence - 1
    print "GAP: #{num_missing} missing sequence IDs. #{last_sequence} != #{first_sequence} + 1. "
    wait_for_missing_ids(db, first_sequence, last_sequence)
    puts
  end
end

Process.waitall

puts
puts "Looking for gaps in sequence IDs in events table:"
ids = db[:events].select(:id).order(:id).all.map { |e| e[:id] }
expected_ids = (ids.min..ids.max).to_a
missing_ids = (expected_ids - ids)
if missing_ids.empty?
  puts "No remaining gaps"
else
  missing_ids.each do |id|
    puts "Unable to find row with sequence ID #{id}"
  end
end
