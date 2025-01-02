RSpec.describe "delegation", isolate: true do
  {
    :default => "/link",
    ::Phlex::SGML => "/link",
    ApplicationView => "/application-link"
  }.each { |mod, path|
    opts = {delegate: [:url]}
    opts[:delegate_on] = mod unless mod == :default

    context "delegate Sinatra's #url helper on #{mod} using #{opts}" do
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
        get path

        expect(last_response.body).to eq('<a href="/bar">link</a>')
        expect(last_response.media_type).to eq("text/html")
      end

      it "works when hosted at a sub-path" do
        get path, {}, {"SCRIPT_NAME" => "/foo"}

        expect(last_response.body).to eq('<a href="/foo/bar">link</a>')
        expect(last_response.media_type).to eq("text/html")
      end

      it "works with full URLs" do
        headers = {
          "HTTP_HOST" => "foo.example.com",
          "SCRIPT_NAME" => "/foo"
        }
        get path, {full: "1"}, headers

        expect(last_response.body).to eq('<a href="http://foo.example.com/foo/bar">link</a>')
        expect(last_response.media_type).to eq("text/html")
      end
    end
  }
end
