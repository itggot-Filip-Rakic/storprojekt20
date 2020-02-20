require "slim"
require "sinatra"
require "sqlite3"
require "bcrypt"
require 'net/http'
require_relative './model.rb'
enable :sessions

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

post("/register") do 
    username = params[:username]
    game_user = params[:game_user]
    password = params[:password]
    password_verify = params[:password_verify]

    response = register(username, game_user, password, password_verify)

    if response.successful then
        session[] = response.data
        redirect("/login")
    else
        session[:regerror] = response.data
        redirect("/users/new")
    end 
end

post("/login_verify") do
    username = params[:username]
    password = params[:password]
    session[:logged_in] = nil
   
    response = login_verify(username, password)

    if response.successful
        session[:logged_in] = username
        redirect("/")
    else
        redirect("/error")
    end
end

post("/logout") do 
    session[:logged_in] = nil
    redirect("/")
end