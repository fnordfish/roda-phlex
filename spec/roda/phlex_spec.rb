# frozen_string_literal: true

RSpec.describe "Roda::RodaPlugins::Phlex" do
  before do
    @test_app_plugins = {phlex: {}}
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

      expect(last_response.body).to eq("<pre>{&quot;a&quot;:&quot;1&quot;,&quot;b&quot;:&quot;2&quot;}</pre>")
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
        <!doctype html><html><head></head><body>Layout Start<p>View Data</p>Layout End</body></html>
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

      it "resets the layout using 'plex_layout nil'" do
        get "/layout/nil"

        expect(last_response.body).to eq("<p>foo</p>")
      end

      it "resets the layout using 'plex_layout false'" do
        get "/layout/false"

        expect(last_response.body).to eq("<p>foo</p>")
      end

      it "phlex_layout sets layout class" do
        get "/layout/phlex_layout_override"
        expect(last_response.body).to eq <<~HTML.chomp
          <html><head><title>phlex_layout_override</title></head><body><main>AlternativeLayout Start<p>content</p>AlternativeLayout End</main></body></html>
        HTML
      end
    end

    describe "configures in the route" do
      it "renders the layout using route default options" do
        get "/layout/merge_opts_route_override"

        expect(last_response.body).to include("<title>route-title</title>")
      end

      it "overwrites route default options" do
        get "/layout/merge_opts_route_override", {title: "custom-title"}
        expect(last_response.body).to include("<title>custom-title</title>")

        # resets to the route default options
        get "/layout/merge_opts_route_override"
        expect(last_response.body).to include("<title>route-title</title>")
      end
    end

    describe "mutating layout options" do
      before do
        @test_app_plugins = {phlex: {layout: AlternativeLayout, layout_opts: {title: +"Default"}}}
      end

      it "carries to the next request when changing the plugin config" do
        get "/layout/mutate_opts/unsafe", {title: "A"}
        expect(last_response.body).to include("<title>A - Default</title>")

        get "/layout/mutate_opts/unsafe", {title: "B"}
        expect(last_response.body).to include("<title>B - A - Default</title>")
      end

      it "does not carry to the next request when changing the shallow copy" do
        get "/layout/mutate_opts/safer", {title: "A"}
        expect(last_response.body).to include("<title>A - Default</title>")

        get "/layout/mutate_opts/safer", {title: "B"}
        expect(last_response.body).to include("<title>B - Default</title>")
      end

      it "does not carry to the next request when creating a new config hash" do
        get "/layout/mutate_opts/safe", {title: "A"}
        expect(last_response.body).to include("<title>A - Default</title>")

        get "/layout/mutate_opts/safe", {title: "B"}
        expect(last_response.body).to include("<title>B - Default</title>")
      end
    end
  end

  context "when using layout_handler" do
    it "renders the layout using the custom handler" do
      get "/layout_handler"

      expect(last_response.body).to eq <<~HTML.chomp
        <html><head><title>phlex_layout_handler override</title></head><body><main>AlternativeLayout Start<p>foo</p>AlternativeLayout End</main></body></html>
      HTML
    end

    it "resets the layout handler to the default using `nil`" do
      get "/layout_handler/reset_via_nil"

      expect(last_response.body).to eq <<~HTML.chomp
        <html><head><title>default-title</title></head><body><main>AlternativeLayout Start<p>foo</p>AlternativeLayout End</main></body></html>
      HTML
    end

    it "resets the layout handler to the default using `:default`" do
      get "/layout_handler/reset_via_nil"

      expect(last_response.body).to eq <<~HTML.chomp
        <html><head><title>default-title</title></head><body><main>AlternativeLayout Start<p>foo</p>AlternativeLayout End</main></body></html>
      HTML
    end
  end
end
