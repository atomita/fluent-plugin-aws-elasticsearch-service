# -*- encoding: utf-8 -*-

describe Fluent::AwsElasticsearchServiceOutput do
  let(:driver)   { Fluent::Test::OutputTestDriver.new(Fluent::AwsElasticsearchServiceOutput, 'test.metrics').configure(config) }
  let(:instance) { driver.instance }

  describe "config" do
    let(:config) do
      %[
      <endpoint>
        url  xxxxxxxxxxxxxxxxxxxx
      </endpoint>
      ]
    end

    it "`endpoint` is array." do
      expect( instance.endpoint ).to eq "xxxxxxxxxxxxxxxxxxxx"
    end

    it "should get room_id" do
      expect( instance.room_id ).to eq "1234567890"
    end

    it "should get body" do
      expect( instance.body ).to eq "some message"
    end
  end
end
