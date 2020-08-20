require "./helper"
require "uuid"

module PlaceOS
  describe Resource do
    it "processes all resources on start up", tags: "resource" do
      models = Array(Basic).new(5) { Basic.new(name: UUID.random.to_s).save! }

      processor = Processor.new
      processor.start
      processor.creates.size.should eq(5)

      processor.stop

      models.each &.destroy

      sleep 0.1

      processor.deletes.should be_empty
    end

    it "listens for changes on resources", tags: "resource" do
      processor = Processor.new.start
      processor.creates.should be_empty
      processor.updates.should be_empty
      processor.deletes.should be_empty

      create_name = UUID.random.to_s
      update_name = UUID.random.to_s
      model = Basic.new(name: create_name).save!

      sleep 0.1

      processor.creates.size.should eq 1
      processor.updates.should be_empty
      processor.deletes.should be_empty

      processor.creates.first.should eq create_name

      model.name = update_name
      model.save!

      sleep 0.1

      processor.creates.size.should eq 1
      processor.updates.size.should eq 1
      processor.deletes.should be_empty

      processor.updates.first.should eq update_name

      model.destroy

      sleep 0.1

      processor.creates.size.should eq 1
      processor.updates.size.should eq 1
      processor.deletes.size.should eq 1

      processor.deletes.first.should eq update_name

      processor.stop
    end

    it "reconnects if db connection is lost", tags: "retry" do
      create_name = UUID.random.to_s
      update_name = UUID.random.to_s
      model = Basic.new(name: create_name).save!
      processor = Processor.new.start

      processor.creates.size.should eq 1

      begin
        RethinkORM::Connection.db.@sock.close
      rescue
      end

      # Retry until connection is up again
      SimpleRetry.try_to do
        begin
          Basic.count
        rescue
          raise "retrying connection"
        end
      end

      model.name = update_name
      model.save!

      sleep 0.1

      processor.updates.size.should eq 1
      processor.stop
      model.destroy
    end
  end
end
