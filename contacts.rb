require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

##### password protection helpers #####

def encrypt_password(password)
  BCrypt::Password.create(password)
end

def correct_password?(password, db_password)
  BCrypt::Password.new(db_password) == password
end

##### path helpers #####

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def credentials_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/users.yml', __FILE__)
  else
    File.expand_path('../users/users.yml', __FILE__)
  end
end

##### signup/signin helpers #####

def load_user_credentials
  YAML.load_file(credentials_path) || {}
end

def add_user(username, password)
  user_credentials = load_user_credentials
  return if user_credentials[username] || username.empty? || password.empty?

  user_credentials[username] = encrypt_password(password)

  File.open(credentials_path, 'w') do |f|
    YAML.dump(user_credentials, f)
  end

  File.open(File.join(data_path, "#{username}.yml"), 'w') do |f|
    YAML.dump({ family: [], friends: [], work: [] }, f)
  end
end

##### signin helpers #####

def redirect_to_index_if_not_signed_in
  redirect '/' unless session[:username]
end

def valid_user?(username, password)
  users = load_user_credentials
  users.key?(username) && correct_password?(password, users[username])
end

##### contacts helpers #####

def load_contacts(username)
  YAML.load_file(File.join(data_path, "#{username}.yml")) || {}
end

def redirect_to_list_if_invalid_category(type)
  redirect '/list' unless %w[all family friends work].include?(type)
end

def all(contacts)
  contacts.values.flatten
end

##### ROUTES #####

get '/' do
  if session[:username]
    redirect '/list'
  else
    erb :index, layout: :layout
  end
end

##### sign up routes #####

get '/signup' do
  erb :signup, layout: :layout
end

post '/signup' do
  new_user = add_user(params[:username], params[:password])

  if new_user
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect '/list'
  else
    session[:message] = "Invalid input! Please try a new username and password."
    erb :signup, layout: :layout
  end
end

##### sign in routes #####

get '/signin' do
  erb :signin, layout: :layout
end

post '/signin' do
  if valid_user?(params[:username], params[:password])
    session[:username] = params[:username]
    session[:message] = "Welcome back!"
    redirect '/list'
  else
    session[:message] = "Invalid input! Please try again."
    erb :signin, layout: :layout
  end
end

##### sign out route #####

post '/signout' do
  session.delete(:username)
  session[:message] = "Goodbye! See you soon."
  redirect '/'
end

##### list routes #####

get '/list' do
  redirect_to_index_if_not_signed_in
  erb :list, layout: :layout
end

get '/categories/:type' do |type|
  redirect_to_index_if_not_signed_in
  redirect_to_list_if_invalid_category(type)

  contacts = load_contacts(session[:username])
  @contacts = (type == 'all' ? all(contacts) : contacts[type.to_sym])
  erb :categories, layout: :layout
end

##### new contact route #####

get '/new' do
  redirect_to_index_if_not_signed_in
  erb :new, layout: :layout
end

post '/new' do
  username = session[:username]
  name = params[:contact].strip
  contacts = load_contacts(username)

  if all(contacts).any? { |contact| contact[:name] == name } || name.empty?
    session[:message] = "You may not enter that name. Please try again."
    erb :new, layout: :layout
  else
    new_contact = { name: name, mobile: params[:mobile], home: params[:home],
                    email: params[:email] }
    contacts[params[:category].to_sym] << new_contact

    File.open(File.join(data_path, "#{username}.yml"), 'w') do |f|
      YAML.dump(contacts, f)
    end

    session[:message] = "#{name} is now in your contact list."
    redirect '/list'
  end
end
