require 'spec_helper'

describe Riak::MapReduce do
  before :each do
    @client = Riak::Client.new
    @backend = double("Backend")
    allow(@client).to receive(:backend).and_yield(@backend)
    @mr = Riak::MapReduce.new(@client)
  end

  it "requires a client" do
    expect { Riak::MapReduce.new }.to raise_error
    expect { Riak::MapReduce.new(@client) }.not_to raise_error
  end

  it "initializes the inputs and query to empty arrays" do
    expect(@mr.inputs).to eq([])
    expect(@mr.query).to eq([])
  end

  it "yields itself when given a block on initializing" do
    @mr2 = nil
    @mr = Riak::MapReduce.new(@client) do |mr|
      @mr2 = mr
    end
    expect(@mr2).to eq(@mr)
  end

  describe "adding inputs" do
    it "returns self for chaining" do
      expect(@mr.add("foo", "bar")).to eq(@mr)
    end

    it "adds bucket/key pairs to the inputs" do
      @mr.add("foo","bar")
      expect(@mr.inputs).to eq([["foo","bar"]])
    end

    it "adds an array containing a bucket/key pair to the inputs" do
      @mr.add(["foo","bar"])
      expect(@mr.inputs).to eq([["foo","bar"]])
    end

    it "adds an object to the inputs by its bucket and key" do
      bucket = Riak::Bucket.new(@client, "foo")
      obj = Riak::RObject.new(bucket, "bar")
      @mr.add(obj)
      expect(@mr.inputs).to eq([["foo", "bar"]])
    end

    it "adds an array containing a bucket/key/key-data triple to the inputs" do
      @mr.add(["foo","bar",1000])
      expect(@mr.inputs).to eq([["foo","bar",1000]])
    end

    it "uses a bucket name as the single input" do
      @mr.add(Riak::Bucket.new(@client, "foo"))
      expect(@mr.inputs).to eq("foo")
      @mr.add("docs")
      expect(@mr.inputs).to eq("docs")
    end

    it "accepts a list of key-filters along with a bucket" do
      @mr.add("foo", [[:tokenize, "-", 3], [:string_to_int], [:between, 2009, 2010]])
      expect(@mr.inputs).to eq({:bucket => "foo", :key_filters => [[:tokenize, "-", 3], [:string_to_int], [:between, 2009, 2010]]})
    end

    it "adds a bucket and filter list via a builder block" do
      @mr.filter("foo") do
        tokenize "-", 3
        string_to_int
        between 2009, 2010
      end
      expect(@mr.inputs).to eq({:bucket => "foo", :key_filters => [[:tokenize, "-", 3], [:string_to_int], [:between, 2009, 2010]]})
    end

    context "using secondary indexes as inputs" do
      it "sets the inputs for equality" do
        expect(@mr.index("foo", "email_bin", "sean@basho.com")).to eq(@mr)
        expect(@mr.inputs).to eq({:bucket => "foo", :index => "email_bin", :key => "sean@basho.com"})
      end

      it "sets the inputs for a range" do
        expect(@mr.index("foo", "rank_int", 10..20)).to eq(@mr)
        expect(@mr.inputs).to eq({:bucket => "foo", :index => "rank_int", :start => 10, :end => 20})
      end

      it "raises an error when given an invalid query" do
        expect { @mr.index("foo", "rank_int", 1.0348) }.to raise_error(ArgumentError)
        expect { @mr.index("foo", "rank_int", Range.new(1.03, 1.05)) }.to raise_error(ArgumentError)
      end
    end

    describe "escaping" do
      before { @oldesc, Riak.escaper = Riak.escaper, CGI }
      after { Riak.escaper = @oldesc }

      context "when url_decoding is false" do
        before { @urldecode, Riak.url_decoding = Riak.url_decoding, false }
        after { Riak.url_decoding = @urldecode }

        it "adds bucket/key pairs to the inputs with bucket and key escaped" do
          @mr.add("[foo]","(bar)")
          expect(@mr.inputs).to eq([["%5Bfoo%5D","%28bar%29"]])
        end

        it "adds an escaped array containing a bucket/key pair to the inputs" do
          @mr.add(["[foo]","(bar)"])
          expect(@mr.inputs).to eq([["%5Bfoo%5D","%28bar%29"]])
        end

        it "adds an object to the inputs by its escaped bucket and key" do
          bucket = Riak::Bucket.new(@client, "[foo]")
          obj = Riak::RObject.new(bucket, "(bar)")
          @mr.add(obj)
          expect(@mr.inputs).to eq([["%5Bfoo%5D", "%28bar%29"]])
        end

        it "adds an escaped array containing a bucket/key/key-data triple to the inputs" do
          @mr.add(["[foo]","(bar)","[]()"])
          expect(@mr.inputs).to eq([["%5Bfoo%5D", "%28bar%29","[]()"]])
        end

        it "uses an escaped bucket name as the single input" do
          @mr.add(Riak::Bucket.new(@client, "[foo]"))
          expect(@mr.inputs).to eq("%5Bfoo%5D")
          @mr.add("docs")
          expect(@mr.inputs).to eq("docs")
        end
      end

      context "when url_decoding is true" do
        before { @urldecode, Riak.url_decoding = Riak.url_decoding, true }
        after { Riak.url_decoding = @urldecode }

        it "adds bucket/key pairs to the inputs with bucket and key unescaped" do
          @mr.add("[foo]","(bar)")
          expect(@mr.inputs).to eq([["[foo]","(bar)"]])
        end

        it "adds an unescaped array containing a bucket/key pair to the inputs" do
          @mr.add(["[foo]","(bar)"])
          expect(@mr.inputs).to eq([["[foo]","(bar)"]])
        end

        it "adds an object to the inputs by its unescaped bucket and key" do
          bucket = Riak::Bucket.new(@client, "[foo]")
          obj = Riak::RObject.new(bucket, "(bar)")
          @mr.add(obj)
          expect(@mr.inputs).to eq([["[foo]","(bar)"]])
        end

        it "adds an unescaped array containing a bucket/key/key-data triple to the inputs" do
          @mr.add(["[foo]","(bar)","[]()"])
          expect(@mr.inputs).to eq([["[foo]","(bar)","[]()"]])
        end

        it "uses an unescaped bucket name as the single input" do
          @mr.add(Riak::Bucket.new(@client, "[foo]"))
          expect(@mr.inputs).to eq("[foo]")
          @mr.add("docs")
          expect(@mr.inputs).to eq("docs")
        end
      end
    end

    context "escaping" do
      before { @oldesc, Riak.escaper = Riak.escaper, CGI }
      after { Riak.escaper = @oldesc }

      it "adds bucket/key pairs to the inputs with bucket and key escaped" do
        @mr.add("[foo]","(bar)")
        expect(@mr.inputs).to eq([["%5Bfoo%5D","%28bar%29"]])
      end

      it "adds an escaped array containing a bucket/key pair to the inputs" do
        @mr.add(["[foo]","(bar)"])
        expect(@mr.inputs).to eq([["%5Bfoo%5D","%28bar%29"]])
      end

      it "adds an object to the inputs by its escaped bucket and key" do
        bucket = Riak::Bucket.new(@client, "[foo]")
        obj = Riak::RObject.new(bucket, "(bar)")
        @mr.add(obj)
        expect(@mr.inputs).to eq([["%5Bfoo%5D", "%28bar%29"]])
      end

      it "adds an escaped array containing a bucket/key/key-data triple to the inputs" do
        @mr.add(["[foo]","(bar)","[]()"])
        expect(@mr.inputs).to eq([["%5Bfoo%5D", "%28bar%29","[]()"]])
      end

      it "uses an escaped bucket name as the single input" do
        @mr.add(Riak::Bucket.new(@client, "[foo]"))
        expect(@mr.inputs).to eq("%5Bfoo%5D")
        @mr.add("docs")
        expect(@mr.inputs).to eq("docs")
      end
    end

    context "when adding an input that will result in full-bucket mapreduce" do
      before { Riak.disable_list_keys_warnings = false }
      after { Riak.disable_list_keys_warnings = true }

      it "warns about list-keys on buckets" do
        expect(@mr).to receive(:warn).twice
        @mr.add("foo")
        @mr.add(Riak::Bucket.new(@client, "foo"))
      end

      it "warns about list-keys on key-filters" do
        expect(@mr).to receive(:warn)
        @mr.filter("foo") { matches "bar" }
      end
    end
  end

  [:map, :reduce].each do |type|
    describe "adding #{type} phases" do
      it "returns self for chaining" do
        expect(@mr.send(type, "function(){}")).to eq(@mr)
      end

      it "accepts a function string" do
        @mr.send(type, "function(){}")
        expect(@mr.query.size).to eq(1)
        phase = @mr.query.first
        expect(phase.function).to eq("function(){}")
        expect(phase.type).to eq(type)
      end

      it "accepts a function and options" do
        @mr.send(type, "function(){}", :keep => true)
        expect(@mr.query.size).to eq(1)
        phase = @mr.query.first
        expect(phase.function).to eq("function(){}")
        expect(phase.type).to eq(type)
        expect(phase.keep).to be_truthy
      end

      it "accepts a module/function pair" do
        @mr.send(type, ["riak","mapsomething"])
        expect(@mr.query.size).to eq(1)
        phase = @mr.query.first
        expect(phase.function).to eq(["riak", "mapsomething"])
        expect(phase.type).to eq(type)
        expect(phase.language).to eq("erlang")
      end

      it "accepts a module/function pair with extra options" do
        @mr.send(type, ["riak", "mapsomething"], :arg => [1000])
        expect(@mr.query.size).to eq(1)
        phase = @mr.query.first
        expect(phase.function).to eq(["riak", "mapsomething"])
        expect(phase.type).to eq(type)
        expect(phase.language).to eq("erlang")
        expect(phase.arg).to eq([1000])
      end
    end
  end

  describe "adding link phases" do
    it "returns self for chaining" do
      expect(@mr.link({})).to eq(@mr)
    end

    it "accepts a WalkSpec" do
      @mr.link(Riak::WalkSpec.new(:tag => "next"))
      expect(@mr.query.size).to eq(1)
      phase = @mr.query.first
      expect(phase.type).to eq(:link)
      expect(phase.function).to be_kind_of(Riak::WalkSpec)
      expect(phase.function.tag).to eq("next")
    end

    it "accepts a WalkSpec and a hash of options" do
      @mr.link(Riak::WalkSpec.new(:bucket => "foo"), :keep => true)
      expect(@mr.query.size).to eq(1)
      phase = @mr.query.first
      expect(phase.type).to eq(:link)
      expect(phase.function).to be_kind_of(Riak::WalkSpec)
      expect(phase.function.bucket).to eq("foo")
      expect(phase.keep).to be_truthy
    end

    it "accepts a hash of options intermingled with the walk spec options" do
      @mr.link(:tag => "snakes", :arg => [1000])
      expect(@mr.query.size).to eq(1)
      phase = @mr.query.first
      expect(phase.arg).to eq([1000])
      expect(phase.function).to be_kind_of(Riak::WalkSpec)
      expect(phase.function.tag).to eq("snakes")
    end
  end

  describe "converting to JSON for the job" do
    it "includes the inputs and query keys" do
      expect(@mr.to_json).to match(/"inputs":/)
    end

    it "maps phases to their JSON equivalents" do
      phase = Riak::MapReduce::Phase.new(:type => :map, :function => "function(){}")
      @mr.query << phase
      expect(@mr.to_json).to include('"source":"function(){}"')
      expect(@mr.to_json).to include('"query":[{"map":{')
    end

    it "emits only the bucket name when the input is the whole bucket" do
      @mr.add("foo")
      expect(@mr.to_json).to include('"inputs":"foo"')
    end

    it "emits an array of inputs when there are multiple inputs" do
      @mr.add("foo","bar",1000).add("foo","baz")
      expect(@mr.to_json).to include('"inputs":[["foo","bar",1000],["foo","baz"]]')
    end

    it "adds the timeout value when set" do
      @mr.timeout(50000)
      expect(@mr.to_json).to include('"timeout":50000')
    end
  end

  it "returns self from setting the timeout" do
    expect(@mr.timeout(5000)).to eq(@mr)
  end

  describe "executing the map reduce job" do
    before :each do
      @mr.map("Riak.mapValues",:keep => true)
    end

    it "submits the query to the backend" do
      expect(@backend).to receive(:mapred).with(@mr).and_return([])
      expect(@mr.run).to eq([])
    end

    it "passes the given block to the backend for streaming" do
      arr = []
      expect(@backend).to receive(:mapred).with(@mr).and_yield("foo").and_yield("bar")
      @mr.run {|v| arr << v }
      expect(arr).to eq(["foo", "bar"])
    end

    it "interprets failed requests with JSON content-types as map reduce errors" do
      allow(@backend).to receive(:mapred).
        and_raise(Riak::ProtobuffsFailedRequest.new(:server_error, '{"error":"syntax error"}'))
      expect{ @mr.run }.to raise_error(Riak::MapReduceError)
      begin
        @mr.run
      rescue Riak::MapReduceError => mre
        expect(mre.message).to include('{"error":"syntax error"}')
      else
        fail "No exception raised!"
      end
    end

    it "re-raises non-JSON error responses" do
      allow(@backend).to receive(:mapred).
        and_raise(Riak::ProtobuffsFailedRequest.new(:server_error, 'Oops, you bwoke it.'))
      expect { @mr.run }.to raise_error(Riak::FailedRequest)
    end
  end
end
