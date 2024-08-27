# frozen_string_literal: true

RSpec.describe "Roda::RodaPlugins::Phlex" do
  before do
    @test_app_plugins = {phlex: {}}
  end

  def app
    build_test_app(@test_app_plugins)
  end

  it "has running roda app" do
    get "/"
    expect(last_response.body).to eq("root")
  end

  context "without the #phlex helper method" do
    it "the Phlex view is rendered as expected" do
      get "/foo"
      expect(last_response.body).to eq("<p>foo</p>")
    end
  end

  context "using Sinatra's #url helper within a Phlex view" do
    [{delegate: :all}, {delegate: [:url]}].each do |opts|
      context "using #{opts}" do
        before do
          @test_app_plugins = {
            sinatra_helpers: {delegate: true},
            phlex: opts
          }
        end

        after do
          @test_app_plugins = {phlex: {}}
        end

        it "works" do
          get "/link"

          expect(last_response.body).to eq('<a href="/bar">link</a>')
          expect(last_response.media_type).to eq("text/html")
        end

        it "works when hosted at a sub-path" do
          get "/link", {}, {"SCRIPT_NAME" => "/foo"}

          expect(last_response.body).to eq('<a href="/foo/bar">link</a>')
          expect(last_response.media_type).to eq("text/html")
        end

        it "works with full URLs" do
          headers = {
            "HTTP_HOST" => "foo.example.com",
            "SCRIPT_NAME" => "/foo"
          }
          get "/link", {full: "1"}, headers

          expect(last_response.body).to eq('<a href="http://foo.example.com/foo/bar">link</a>')
          expect(last_response.media_type).to eq("text/html")
        end
      end
    end
  end

  context "when passing content_type" do
    it "responds correctly" do
      get "/xml"

      expect(last_response.body).to eq("<p>foo</p>")
      expect(last_response.media_type).to eq("application/xml")
    end
  end

  context "with a Phlex::SVG view" do
    it "responds with the correct content type by default" do
      get "/svg"

      expect(last_response.body).to start_with("<svg><rect")
      expect(last_response.media_type).to eq("image/svg+xml")
    end

    it "can also specify a content type" do
      get "/svg/plain"

      expect(last_response.body).to start_with("<svg><rect")
      expect(last_response.media_type).to eq("text/plain")
    end
  end

  context "when the thing passed to #phlex isn't a Phlex instance" do
    it "raises an error and displays the input string" do
      expect {
        get "/error", {type: "string"}
      }.to raise_error(Roda::RodaPlugins::Phlex::TypeError, %r{"<p>foo</p>"})
    end

    it "limits the input when it's a long string" do
      expect {
        get "/error", {type: "string-long"}
      }.to raise_error(Roda::RodaPlugins::Phlex::TypeError, /"<p>a b c d e f g h i j k l m n …/)
    end

    it "raises an error and displays the input class" do
      expect {
        get "/error", {type: "phlex-class"}
      }.to raise_error(Roda::RodaPlugins::Phlex::TypeError, /FooView/)
    end
  end

  context "accessing Roda's app.request.params" do
    it "works" do
      get "/more", {a: 1, b: 2}

      expect(last_response.body).to eq("<pre>{&quot;a&quot;=&gt;&quot;1&quot;, &quot;b&quot;=&gt;&quot;2&quot;}</pre>")
      expect(last_response.media_type).to eq("text/html")
    end
  end

  context "when streaming", type: :feature do
    it "outputs the full response" do
      last_response = get_capybara("/stream")

      expect(last_response.body).to eq <<~HTML.chomp
        <html><head><title>Streaming</title></head><body><p>1</p><p>2</p></body></html>
      HTML

      # Indicates that streaming is being used.
      expect(last_response["Content-Length"]).to be_nil
    end

    it "outputs the full response with an explicit layout" do
      last_response = get_capybara("/stream/explicit")
      expect(last_response.body).to eq <<~HTML.chomp
        <!DOCTYPE html><html><head></head><body>Layout Start<p>View Data</p>Layout End</body></html>
      HTML
      # Indicates that streaming is being used.
      expect(last_response["Content-Length"]).to be_nil
    end
  end

  context "when using layout" do
    describe "configured as plugin option" do
      before do
        @test_app_plugins = {phlex: {layout: HomepageLayout}}
      end

      it "renders the layout using default options" do
        get "/layout"

        expect(last_response.body).to eq <<~HTML.chomp
          <html><head><meta charset="UTF-8"><meta http-equiv="UTF-8" content="IE=edge"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>default-title</title></head><body><p>foo</p></body></html>
        HTML
      end

      it "overwrites default options" do
        get "/layout", {title: "custom-title"}

        expect(last_response.body).to eq <<~HTML.chomp
          <html><head><meta charset="UTF-8"><meta http-equiv="UTF-8" content="IE=edge"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>custom-title</title></head><body><p>foo</p></body></html>
        HTML
      end

      it "resets the layout" do
        get "/layout/none"

        expect(last_response.body).to eq("<p>foo</p>")
      end
    end

    describe "configures in the route" do
      it "renders the layout using route default options" do
        get "/layout/route_override"

        expect(last_response.body).to include("<title>route-title</title>")
      end

      it "overwrites route default options" do
        get "/layout/route_override", {title: "custom-title"}
        expect(last_response.body).to include("<title>custom-title</title>")

        # resets to the route default options
        get "/layout/route_override"
        expect(last_response.body).to include("<title>route-title</title>")
      end
    end
  end
end
