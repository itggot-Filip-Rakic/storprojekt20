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

get('/users/show/:user_id') do 
    user_id = params[:user_id].to_i

    if user_id == session[:user_id].to_i
        my_posts = get_from_db("*","post","user_id",user_id)
    else
        my_posts = get_public_posts(user_id)
    end
    user = get_from_db("username","user","user_id",user_id)[0]

    slim(:"users/show",locals:{my_posts: my_posts,user: user})
end

get('/posts/new') do 
    if not_authenticated(session[:user_id])
        redirect('/')
    end
    slim(:"posts/new")
end

post('/posts/new') do
    name = params[:name]
    text = params[:written]
    pstatus = params[:public]
    time = Time.now.to_i
    
    session[:post_created] = add_new_post(name,text,session[:user_id],pstatus,time)

    redirect("/posts/new")
end

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
    slim(:"post/show",locals:{post_info:post_data, userdata:userdata, no_authentication:no_authentication})
end

get("/posts/:post_id/edit") do 
    post_data = session[:edit_post]
    no_authentication = false
    if post_data["user_id"] != session[:user_id] && session[:rank] != "admin"
        no_authentication = true
        ad_data = nil
    end
    slim(:"posts/edit",locals:{post_info:post_data,no_authentication:no_authentication})
end

post('/posts/:post_id/update') do
    post_id = session[:edit_post]["post_id"]
 
    validation = validate_post(params[:name],params[:written],session[:edit_ad])
    if validation.nil?
        update_post(post_id,params[:written])
    else
        session[:edited_post] = validation
    end
    redirect back
end


post('/posts/destory') do 
    post_id = session[:edit_post]["post_id"]
    delete_post(post_id,session[:user_id],session[:rank])
    redirect('/')
end