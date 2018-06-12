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
    assert_includes last_response.body, ">Family</a></h2></div>"
  end

  def test_sign_in_page
    get "/signin"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, ">Username: </label>"
    assert_includes last_response.body, ">Sign in</button>"
  end

  def test_sign_in_action
    post "/signin", username: 'admin', password: 'secret'
    assert_equal 302, last_response.status

    get last_response['location']
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Welcome back!"
  end

  def test_sign_in_invalid_user
    post "/signin", username: 'steve', password: 'beesknees'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Invalid input! Please try again."
  end

  def test_sign_in_invalid_input_whitespace
    post "/signin", username: '  ', password: '  '
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Invalid input! Please try again."
  end

  def test_sign_out
    get "/", {}, admin_credentials
    assert_equal 302, last_response.status

    get last_response['location']
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, ">Family</a></h2></div>"

    post '/signout'
    assert_equal 302, last_response.status

    get last_response['location']
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Want to be a registered user?"
  end

  def test_contact_list_signed_in
    get '/list', {}, admin_credentials
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, ">Family</a></h2></div>"
    assert_includes last_response.body, "<em>Want to add a new contact? </em>"
  end

  def test_contact_list_signed_out
    get '/list'
    assert_equal 302, last_response.status

    get last_response['location']
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Want to be a registered user?"
  end

  def test_new_signed_out
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    get last_response['location']
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Want to be a registered user?"
  end

  def test_new_page_signed_in
    get "/new", {}, admin_credentials
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, ">Add the contact details below:</h3>"
  end

  def test_new_contact_invalid_existing
    get '/', {}, admin_credentials

    post "/new", contact: 'mike', mobile: '555555555555', category: 'friends'
    assert_equal 302, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_equal "mike is now in your contact list.", session[:message]

    post "/new", contact: 'mike', mobile: '555555555555', category: 'friends'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "You may not enter that name."
  end

  def test_new_contact_invalid_whitespace
    get '/', {}, admin_credentials

    post "/new", contact: '   ', mobile: '555555555555', category: 'friends'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "You may not enter that name."
  end

  def test_new_contact
    get '/', {}, admin_credentials

    post "/new", contact: 'mike', mobile: '555555555555', category: 'friends'
    assert_equal 302, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_equal "mike is now in your contact list.", session[:message]
  end

  def test_categories_signed_out
    get "/categories/family"
    assert_equal 302, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    get last_response['location']
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Want to be a registered user?"
  end

  def test_categories_signed_in
    get '/', {}, admin_credentials

    post "/new", contact: 'mike', mobile: '555555555555', category: 'friends'
    assert_equal 302, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_equal "mike is now in your contact list.", session[:message]

    get "/categories/friends"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Mobile phone: 555555555555"
  end
end
