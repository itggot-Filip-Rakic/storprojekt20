require "sqlite3"
require "bcrypt"
require 'net/http'

$db = SQLite3::Database.new("db/database.db")
$db.results_as_hash = true

class ModelResponse
    @successful
    @data
    def initialize(successful, data)
      @successful = successful
      @data = data
    end
    def successful; @successful end
    def data; @data end
  end

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

public def loggedinq(logged_in)
    user_id = $db.execute("SELECT user_id FROM user WHERE username LIKE ?", logged_in)[0]["user_id"]
end 


public def register(username, game_user, password, password_verify)
    exist_user = $db.execute("SELECT username FROM user WHERE username = ?", username)
    exist_gameuser = $db.execute("SELECT gameuser FROM user WHERE gameuser = ?", game_user )

    if !exist_user.empty?
        return ModelResponse.new(false, "Username is already taken!")
    elsif password != password_verify
        return ModelResponse.new(false, "Password doesn't match!")
    elsif validate_game_user(game_user) == false
        return ModelResponse.new(false, "Ingame username dosen't exist! :O")
    end

    password_scramble = BCrypt::Password.create(password)

    if exist_user.empty?
        $db.execute("INSERT INTO user(username, password, gameuser) VALUES(?, ?, ?)", username, password_scramble, game_user)
        return ModelResponse.new(true, nil)
    end
    return ModelResponse.new(false, "How did u get here??")
end

public def login_verify(username, password)
    exist = $db.execute("SELECT username FROM user WHERE username LIKE ?", username)
    if exist.empty?
        return ModelResponse.new(false, nil)
    end

    controll_password = $db.execute("SELECT password FROM user WHERE username LIKE ?", username)[0]["password"]

    if BCrypt::Password.new(controll_password) == password
        return ModelResponse.new(true, nil)
    else
        return ModelResponse.new(false, nil)
        redirect("/error")
    end
end