module Model
    require "sqlite3"
    require "bcrypt"
    require 'net/http'
    require 'byebug'

    #
    # Connects to the database
    #
    # @return [Hash] Returns the database as a hash
    #    
    def db()
        db = SQLite3::Database.new("db/database.db")
        db.results_as_hash = true
        return db
    end

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

    #
    # Get different items from database depending on the arguments
    #
    # @param [String] column The column to be searched
    # @param [String] table The table to be searched
    # @param [String] where Optional argument if you want to retrieve SQL rows where a specific value matches
    # @param [String] value The value to be searched
    #
    # @return [Hash] A hash with retrieved items from SQL database
    #
    def get_from_db(column, table, where, value)
        if where.nil? || value.nil?
            return db.execute("SELECT #{column} FROM #{table}")
        else
            return db.execute("SELECT #{column} FROM #{table} WHERE #{where} = ?",value)
        end
    end

    #
    # Validates registration input and scrambles password.
    #
    # @param [String] exist_user If a user with that username already exist
    # @param [String] exist_gameuser If a user with that ingame username already exist
    # @param [String] existing_phone If a user with that phone number already exist
    # @param [String] password_scramble The digested password to be saved
    #
    # @return [String] Returns a error message if one of the statemenats is true. Dosn't return anything if all variables is validated correctly.
    #
    public def register(username, game_user, password, password_verify)
        exist_user = db.execute("SELECT username FROM user WHERE username = ?", username)
        exist_gameuser = db.execute("SELECT gameuser FROM user WHERE gameuser = ?", game_user )

        if !exist_user.empty?
            return ModelResponse.new(false, "Username is already taken!")
        elsif password != password_verify
            return ModelResponse.new(false, "Password doesn't match!")
        elsif validate_game_user(game_user) == false
            return ModelResponse.new(false, "Ingame username dosen't exist! :O") 
        end

        password_scramble = BCrypt::Password.create(password)

        if exist_user.empty?
            begin
                db.execute("INSERT INTO user(username, password, gameuser) VALUES(?, ?, ?)", username, password_scramble, game_user)
            rescue => exception
                p exception
                p exception.message
                if (exception.message == "UNIQUE constraint failed: user.gameuser")
                    return ModelResponse.new(false, "Ingame username already taken!")
                end
            end
            return ModelResponse.new(true, nil)
        end
        return ModelResponse.new(false, "How did u get here??")
    end

    #
    # Validates and verify login.
    #
    # @param [String] exist If a user with that username already exist
    # @param [String] checks if password matches to database
    #
    # @return [String] Returns a error message if one of the statemenats is true. Dosn't return anything if all variables is validated correctly.
    #
    public def login_verify(username, password)
        exist = db.execute("SELECT username FROM user WHERE username LIKE ?", username)
        if exist.empty?
            return ModelResponse.new(false, nil)
        end

        controll_password = db.execute("SELECT password FROM user WHERE username LIKE ?", username)[0]["password"]

        if BCrypt::Password.new(controll_password) == password
            return ModelResponse.new(true, nil)
        else
            return ModelResponse.new(false, nil)
        end
    end

        #
        # Gets all the public posts from a user
        #
        # @param [Integer] user_id Id of a user
        #
        # @return [Hash] Hash with all the public posts of specific user.
        #
    def get_public_posts(user_id)
        return db.execute("SELECT * FROM post WHERE user_id = ? AND public = ?",user_id, "on")
    end

    def add_new_post(name,written,user_id,pstatus,time)
        db.execute("INSERT INTO post (name, written,user_id,public,time) VALUES (?, ?, ?, ?, ?)", name, written, user_id, pstatus, time)
        return "Ur post has been saved"
    end 

    #
    # Validates input from a new post creation or a update of an post.
    #
    # @param [String] name The name of the post title
    # @param [String] written The text of an post
    #
    # @return [String,nil] Returns the error message if the validation is not successful. Otherwise return nil.
    #
    def validate_post(name,written)
        if name.empty? || written.empty?
            return "You missed to fill out a field"
        elsif name.length >= 500 || written.length >= 5000
            return "U have reached the charater limit"
        else
            return nil
        end
    end

    #
    # Updates potst with updated information
    #
    # @param [Integer] post_id Post to update
    # @param [String] name Name of post
    # @param [String] written text of post
    #
    def update_post(post_id,name,written)
        db.execute("UPDATE post SET name = ?,written = ? WHERE post_id = ?",name,written,post_id)
    end

    #
    # Checks if the user is allowed to delete the post the proceeds to deletes the post.
    #
    # @param [Integer] post_id Post to be deletetd
    # @param [String] current_user Name of the current user logged in
    # @param [String] rank If the person has admin he/she can delete ad anyway.
    #
    def delete_post(post_id,current_user,rank)
        owner_id = get_from_db("user_id","post","post_id",post_id)[0]["user_id"]
        if current_user == owner_id || rank == "admin"
            db.execute("PRAGMA foreign_keys = ON")
            db.execute("DELETE FROM post WHERE post_id = ?", post_id)
            p "success"
        else
            p "fail"
        end
    end

    #
    # Checks if user is authenticated
    #
    # @param [Integer] user_id User id to verify
    #
    # @return [Boolean] Returns true or false
    #
        def not_authenticated(user_id)
            if user_id == nil
                return true
            else
                return false
            end
        end

end