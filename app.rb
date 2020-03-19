require "slim"
require "sinatra"
require "byebug"
require "sqlite3"
require "bcrypt"
require 'net/http'
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

get("/users/new") do 
    slim(:"users/new")
end

get("/users/index") do 
    slim(:"users/index")
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

post("/users/login") do
    username = params[:username]
    password = params[:password]
    
    existing_username = get_from_db("username","user","username",username)
    
    if existing_username.empty?
        session[:login_error] = "Username or password wrong"
        redirect("/users/error")
    end

    password_for_user = get_from_db("password_digest","user","username",username)[0]["password_digest"]

    if BCrypt::Password.new(password_for_user) != password
        session[:login_error] = "Username or password wrong"
        redirect("/users/error")
    end

    session[:user_id] = get_from_db("user_id","user","username",username)[0]["user_id"]
end

post("/users/logout") do 
    session.destroy
    redirect("/")
end