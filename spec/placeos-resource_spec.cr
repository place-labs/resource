require "./helper"
require "uuid"

module PlaceOS
  describe Resource do
    before_each do
      Basic.clear
      sleep 0.2
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
        sleep 0.2
        models = Array(Basic).new(count) { |i| Basic.new(name: "test-#{i + 1}") }
        models.each(&.save!)
        sleep 0.2
        processor.creates.size.should eq(count)
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
