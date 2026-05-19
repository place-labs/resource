require "./helper"
require "uuid"

module PlaceOS
  describe Resource do
    before_each do
      Basic.clear
      sleep 200.milliseconds
    end

    describe "#startup_finished?", tags: "resource" do
      it "test startup_finished?" do
        Array(Basic).new(3) { Basic.new(name: UUID.random.to_s).save! }
        processor = Processor.new
        processor.startup_finished?.should be_false
        processor.start
        processor.creates.size.should eq(3)
        processor.startup_finished?.should be_true
        processor.stop
        processor.startup_finished?.should be_false
      end
    end

    describe "#start", tags: "resource" do
      it "processes all resources on start up" do
        models = Array(Basic).new(5) { Basic.new(name: UUID.random.to_s).save! }

        processor = Processor.new
        processor.start
        processor.creates.size.should eq(5)

        processor.stop

        models.each &.destroy

        sleep 100.milliseconds

        processor.deletes.should be_empty
      end

      it "received changes on resource via Model ChangeFeed" do
        count = 1000
        changefeed = Basic.changes
        chan = Channel(Nil).new
        received = 0
        spawn do
          changefeed.on do |_change|
            received += 1
            chan.send(nil) if received == count
          end
        end
        Fiber.yield

        models = Array(Basic).new(count) { |i| Basic.new(name: "test-#{i + 1}") }
        models.each(&.save!)
        chan.receive
        received.should eq(count)
        changefeed.try &.stop
      end

      it "should receive all changes on resources" do
        count = 1000
        processor = Processor.new.start
        processor.creates.should be_empty
        sleep 200.milliseconds
        models = Array(Basic).new(count) { |i| Basic.new(name: "test-#{i + 1}") }
        models.each(&.save!)
        sleep 200.milliseconds
        processor.creates.size.should eq(count)
        processor.stop
      end

      it "survives consecutive raises in the dispatch loop without recursing", tags: "resource" do
        # Regression: `watch_processing` previously rescued errors by recursively
        # calling itself, growing the fiber stack on every raise until overflow.
        # The fix wraps the loop in `SimpleRetry` with a 1s max backoff.
        processor = FaultyProcessor.new
        processor.fault_quota = 5
        processor.start

        # First model is consumed by an injected fault.
        # `_spawn_event` raises before `_process_event` runs.
        # After `fault_quota` faults the loop keeps draining the channel.
        names = Array(String).new(processor.fault_quota + 1) { UUID.random.to_s }
        names.each do |name|
          Basic.new(name: name).save!
          # Give the worker fiber a chance to drain between writes so the
          # injected faults align with the first few events.
          sleep 50.milliseconds
        end

        # Allow the final non-faulting event to complete (worst-case backoff
        # after 5 faults: 10+20+40+80+160 = 310ms, plus processing slack).
        sleep 1.second

        processor.faults_emitted.get.should eq(processor.fault_quota)
        processor.creates.size.should be >= 1
        # The worker fiber is still alive and processing — the very next event
        # also gets through.
        followup = UUID.random.to_s
        Basic.new(name: followup).save!
        sleep 300.milliseconds
        processor.creates.should contain(followup)

        processor.stop
      end

      it "listens for changes on resources" do
        processor = Processor.new.start
        processor.creates.should be_empty
        processor.updates.should be_empty
        processor.deletes.should be_empty

        create_name = UUID.random.to_s
        update_name = UUID.random.to_s
        sleep 100.milliseconds

        model = Basic.new(name: create_name).save!
        sleep 200.milliseconds

        processor.creates.size.should eq 1
        processor.updates.should be_empty
        processor.deletes.should be_empty

        processor.creates.first.should eq create_name

        model.name = update_name
        model.save!

        sleep 200.milliseconds

        processor.creates.size.should eq 1
        processor.updates.size.should eq 1
        processor.deletes.should be_empty

        processor.updates.first.should eq update_name

        model.destroy

        sleep 200.milliseconds

        processor.creates.size.should eq 1
        processor.updates.size.should eq 1
        processor.deletes.size.should eq 1

        processor.deletes.first.should eq update_name

        processor.stop
      end
    end
  end
end
