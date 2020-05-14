require "slim"
require "sinatra"
require "byebug"
require "sqlite3"
require "bcrypt"
require 'net/http'
require "byebug"
require_relative './model.rb'
include Model

enable :sessions


before do 
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

#before('/') do
#     session[:user_id] = 2
#     session[:username] = "Edvin"
#end

get("/") do 
    slim(:index)
end

# 
# Shows registration page where you can create a new account. 
# 
get("/users/new") do 
    slim(:"users/new")
end

# 
# Takes form input from '/users/new' with user information and validates it, and then ads it to the database
# 
# @param [String] username user username
# @param [String] password user password
# @param [String] game_user user ingame name
# @param [String] password_verify user password verification
# 
# @see Model#get_from_db
# @see Model#register
# 
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
post('/users') do
    username = params[:username]
    password = params[:password]
    
    existing_username = get_from_db("username","user","username",username)
    
    if existing_username.empty?
        session[:login_error] = "Username or password wrong"
        redirect("/users/")
    end

    password_for_user = get_from_db("password","user","username",username)[0]["password"]

    if BCrypt::Password.new(password_for_user) != password
        session[:login_error] = "Username or password wrong"
        redirect("/users/")
    end

    session[:user_id] = get_from_db("user_id","user","username",username)[0]["user_id"]

    session[:username] = username
    session[:rank] = get_from_db("rank","user","username",username)[0]["rank"]
    p session[:rank]
    redirect("/")
    
end


# 
# Logs out user and destroys all session cookies
# 
post("/logout") do 
    session.destroy
    redirect("/")
end

# 
# Shows all Posts of a specific user
# 
# @params [Integer] user_id User id to show profile of.
# 
# @see Model#get_from_db
# @see Model#get_public_posts
# 
get('/users/show/:user_id') do 
    user_id = params[:user_id].to_i

    if user_id == session[:user_id].to_i
        my_posts = get_from_db("*","post","user_id",user_id)
    else
        my_posts = get_public_posts(user_id)
    end
    user = get_from_db("username","user","user_id",user_id)[0]
    p user
    p my_posts

    slim(:"users/show",locals:{my_posts: my_posts,user: user})
end

# 
# Displays '/posts/new' page where a user can create post. But if you're not logged in it sends you back to the home page '/' 
# 
# @see Model#not_authenticated
#
get('/posts/new') do 
    if not_authenticated(session[:user_id])
        redirect('/')
    end
    slim(:"posts/new")
end

# 
# Receives form input from '/posts/new' and creates a new post based on the variables.
# 
# @param [String] name Name of the post
# @param [String] written Description of post
# @param [String] public If the post should be public or private
# @param [String] time saves time when created
# 
# @see Model#get_ad_id
# @see Model#validate_ad_items
# @see Model#add_new_ad
# @see Model#new_ad_to_categories
# 
post('/posts/new') do
    name = params[:name]
    text = params[:written]
    pstatus = params[:public]
    time = Time.now.to_i
    
    session[:post_created] = add_new_post(name,text,session[:user_id],pstatus,time)

    redirect("/posts/new")
end

# 
# Displays a specific post based on the post_id provided in the path
# 
# @param [Integer] :post_id The id of a specific ad
# 
# @see Model#get_from_db
# 
get("/posts/:post_id") do
    no_authentication = false
    post_id = params["post_id"]
    post_data = get_from_db("*","post","post_id",post_id)[0]

    if post_data != nil
        userdata = get_from_db("*","user","user_id",post_data["user_id"])[0]
        if post_data ["public"] == nil && post_data["user_id"] != session[:user_id]
            no_authentication = true
            post data = nil
        end
    end
    session[:edit_post] = post_data
    slim(:"posts/show",locals:{post_info:post_data, userdata:userdata, no_authentication:no_authentication})
end

# 
# Displays the edit page for a specific post.
# It also checks if you have the corret authorization to edit the post.
# 
# @param [Integer] :post_id Id of the post thats going to be edited.
# 
get("/posts/:post_id/edit") do 
    post_data = session[:edit_post]
    no_authentication = false
    if post_data["user_id"] != session[:user_id] && session[:rank] != "admin"
        no_authentication = true
        post_data = nil
    end
    slim(:"posts/edit",locals:{post_info:post_data,no_authentication:no_authentication})
end

# 
# Takes input from '/posts/:post_id/edit' and validates it and updates the post information in the database. 
# 
# @param [Integer] :post_id Id of the post thats going to be updated.
# 
# @see Model#validate_post
# @see Model#update_post
# 
post('/posts/:post_id/update') do
    post_id = session[:edit_post]["post_id"] 
    validation = validate_post(params[:name],params[:written])
    if validation.nil?
        update_post(post_id,params[:name],params[:written])
    else
        session[:edited_post] = validation
    end
    redirect back
end

# 
# Deletes a specified post.
# 
# @see Model#delete_post
# 
post('/posts/destory') do 
    post_id = session[:edit_post]["post_id"]
    delete_post(post_id,session[:user_id],session[:rank])
    redirect('/')
end