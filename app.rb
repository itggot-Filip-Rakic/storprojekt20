require "slim"
require "sinatra"
require "sqlite3"
require "bcrypt"
require 'net/http'
enable :sessions

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true


def validate_game_user(game_user)
    uri = URI("https://api.mojang.com/users/profiles/minecraft/#{game_user}")
    Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new uri
      
        response = http.request request # Net::HTTPResponse object
        p response.code
        return response.code == "200"
      end
      return false
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

get("/login") do
    update_id = params[:update_content].to_i
    
    if !session[:logged_in].nil?
        user_id = db.execute("SELECT user_id FROM user WHERE username LIKE ?", session[:logged_in])[0]["user_id"]
    end
    slim(:login, locals:{update_id: update_id})
end

post("/register") do 
    username = params[:username]
    game_user = params[:game_user]
    password = params[:password]
    password_verify = params[:password_verify]

    exist_user = db.execute("SELECT username FROM user WHERE username = ?", username)
    exist_gameuser = db.execute("SELECT gameuser FROM user WHERE gameuser = ?", game_user )

    if !exist_user.empty?
        session[:regerror] = "Username is already taken!"
        redirect("/users/new")
    elsif password != password_verify
        session[:regerror] = "Password doesn't match!"
        redirect("/users/new")
    elsif validate_game_user(game_user) == false
        session[:regerror] = "Ingame username dosen't exist! :O"
        redirect("/users/new")
    end
    
    
    password_scramble = BCrypt::Password.create(password)

    if exist_user.empty?
        db.execute("INSERT INTO user(username, password, gameuser) VALUES(?, ?, ?)", username, password_scramble, game_user)
    else
        redirect("/users/username_exist")
    end
    redirect("/login")
end

post("/login_verify") do
    username = params[:username]
    password = params[:password]
    session[:logged_in] = nil

    #Kollar ifall Användaren finns
    exist = db.execute("SELECT username FROM user WHERE username LIKE ?", username)
    if exist.empty?
        redirect("/users/error")
    end

    #Hämtar användarens lödsenord för jämförelse
    controll_password = db.execute("SELECT password FROM user WHERE username LIKE ?", username)[0]["password"]

    if BCrypt::Password.new(controll_password) == password
        session[:logged_in] = username
        redirect("/login")
    else
        redirect("/error")
    end
end

post("/logout") do 
    session[:logged_in] = nil
    redirect("/")
end