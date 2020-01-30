require "slim"
require "sinatra"
require "sqlite3"
require "bcrypt"
enable :sessions

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true

get("/") do 
    slim(:index)
end

get("/reglog") do 
    slim(:reglog)
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
    password = params[:password]
    password_verify = params[:password_verify]

    if password != password_verify || username == "" || password == ""
        redirect("/password_do_not_match")
    end

    exist = db.execute("SELECT username FROM user WHERE username LIKE ?", username)
    password_scramble = BCrypt::Password.create(password)

    if exist.empty?
        db.execute("INSERT INTO user(username, password) VALUES(?, ?)", username, password_scramble)
    else
        redirect("/username_exist")
    end
    redirect("/")
end

post("/login_verify") do
    username = params[:username]
    password = params[:password]
    session[:logged_in] = nil

    #Kollar ifall Användaren finns
    exist = db.execute("SELECT username FROM user WHERE username LIKE ?", username)
    if exist.empty?
        redirect("/error")
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

get("/error") do
    slim(:error)
end

get("/password_do_not_match") do 
    slim(:password_do_not_match)
end

get("/username_exist") do 
    slim(:username_exist)
end

post("/logout") do 
    session[:logged_in] = nil
    redirect("/")
end