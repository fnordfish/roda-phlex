RSpec.describe "errors when delegate is not set on correct base class", isolate: true do
  before do
    @test_app_plugins = {
      sinatra_helpers: {delegate: true},
      phlex: {delegate: :url, delegate_on: ApplicationView}
    }
  end

  after do
    @test_app_plugins = {phlex: {}}
  end

  it "raises an error" do
    expect {
      get "/link" # expects delegates on Phlex::SGML
    }.to raise_error(NoMethodError, /undefined method `url'/)
  end
end
