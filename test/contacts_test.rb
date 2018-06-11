ENV["RACK_ENV"] = "test"

require 'fileutils'

require "minitest/autorun"
require "rack/test"

require_relative "../contacts"

class ContactsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
    add_user('admin', 'secret')
  end

  def teardown
    FileUtils.rm_rf(data_path)

    File.open(credentials_path, 'w') do |f|
      YAML.dump({}, f)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_credentials
    { "rack.session" => { username: "admin", password: "secret" } }
  end

  def test_index_signed_out
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Want to be a registered user?"
  end

  def test_index_signed_in
    get "/", {}, admin_credentials
    assert_equal 302, last_response.status

    get last_response['location']
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<p>hello world</p>"
  end
end
