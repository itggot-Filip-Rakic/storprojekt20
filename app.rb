require "slim"
require "sinatra"
require "byebug"
require "sqlite3"
require "bcrypt"
require 'net/http'
require "byebug"
require_relative './model.rb'

enable :sessions


before do 
    if session[:user_id] != nil 
        redirect('/')
    end
        if request.post?
            if session[:last_action].nil?
                session[:last_action] = Time.now
            end
            if ((session[:last_action] + 2) > Time.now())
                sleep(1)
            end
            session[:last_action] = Time.now()
            session[:regerror] = nil
        end
    end

get("/") do 
    slim(:index)
end

# 
# Shows registration page where you can create a new account. 
# 
get("/users/new") do 
    slim(:"users/new")
end

get("/users/error") do
    slim(:"users/error")
end

post("/users/register") do 
    username = params[:username]
    game_user = params[:game_user]
    password = params[:password]
    password_verify = params[:password_verify]

    response = register(username, game_user, password, password_verify)

    if response.successful then
        session[:logged_in] = response.data
        redirect("/")
    else
        session[:regerror] = response.data
        redirect("/users/new")
    end 
end

# 
# Displays login page
# 
get("/users/") do 
    slim(:"users/index")
end

#  
# Takes input from '/users/' and logs a user in with information.
# First it checks if username is in database. Then it checks if the digested password is equal to the digested password in the database.
# 
# @param [String] username Users inputted username
# @param [String] password Users inputted password
# 
# @see Model#get_from_db
# 
post('/users/') do
    username = params[:username]
    password = params[:password]
    
    existing_username = get_from_db("username","user","username",username)
    
    if existing_username.empty?
        session[:login_error] = "Username or password wrong"
        redirect("/users/")
    end

    password_for_user = get_from_db("password_digest","user","username",username)[0]["password_digest"]

    if BCrypt::Password.new(password_for_user) != password
        session[:login_error] = "Username or password wrong"
        redirect("/users/")
    end

    session[:user_id] = get_from_db("user_id","user","username",username)[0]["user_id"]

    session[:username] = username
    session[:rank] = get_from_db("rank","user","username",username)[0]["rank"]
    redirect("/")
end

# 
# Logs out user and destroys all session cookies
# 
post("/users/logout") do 
    session.destroy
    redirect("/")
end