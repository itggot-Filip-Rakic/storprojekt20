require "slim"
require "sinatra"
require "byebug"
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
    session[:logged_in] = nil
   
    response = login_verify(username, password)

    if response.successful
        session[:logged_in] = username
        redirect("/")
    else
        redirect("/error")
    end
end

post("/users/logout") do 
    session[:logged_in] = nil
    redirect("/")
end