require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do 
  enable :sessions
  set :session_secret, 'secret'
end

 before do
  path = request.path
  /\/lists\/(?<list_id>\d)+/=~ path
  @list_id = list_id.to_i
  
  session[:lists] ||= []
  # @lists = sort_lists_by_completion_status(session[:lists])
  @lists = session[:lists]
  @list = @lists[@list_id]
end

get "/" do
  redirect "/lists"
end

helpers do 
  
  # Return an array of error msgs if the name is invalid, otherwise return nil.
  def error_for_list_name(name)
    errors = []

    if !(1..100).cover?(name.length)
      errors << "The list name must be between 1 and 100 characters long."
    elsif @lists.any? { |list| list[:name].downcase == name.downcase }
      errors << "There is already a list by that name."
    end
    errors.empty? ? nil : errors
  end

  # Return an array of error messages if the todo name is invalid,
  # otherwise return nil
  def error_for_todo(name)
    errors = []
    if !(1..100).cover?(name.length)
      errors << "The todo must be between 1 and 100 characters long."
    end
    errors.empty? ? nil : errors
  end

  # Returns true if all todos are marked as complete, false otherwise
  def all_todos_complete?(todos)
    todos.all? { |todo| todo[:completed]}
  end

  # Returns 'complete' if list has at least one todo and all todos 
  # are marked completed
  def list_completion_status(list)
    "complete" if !list[:todos].empty? && all_todos_complete?(list[:todos])
  end

  def list_complete?(list)
    list_completion_status(list) == 'complete'
  end

  # Sort list order by completion status - 'completed' at the bottom
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition.with_index do |list, index|
      list[:id] = index
      list_complete?(list)
    end
    
    incomplete_lists.each(&block)
    complete_lists.each(&block)

      # puts "Complete lists: #{complete_lists}"
      # puts "Incomplete lists: #{incomplete_lists}"
  end

  # sort todos order by completion status - 'completed' at bottom
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    
    incomplete_todos.each_with_index(&block)
    complete_todos.each_with_index(&block)
  end

  # Return the ratio of uncompleted_todos/total_todos
  def todo_completion_ratio(todos)
    todos_left_to_do = todos.count { |todo| todo[:completed] == false }
    total_todo_count = todos.count
    "#{todos_left_to_do}/#{total_todo_count}"
  end

  def todo_completion_status(todo)
    "complete" if todo[:completed]
  end
end

# View list of lists
get "/lists" do 
  
  erb :lists, layout: :layout
end

# Create a new list
post "/lists" do 
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    
    session[:lists] << {name: list_name, todos: [] }
    
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Render the new list form
get "/lists/new" do 
  erb :new_list, layout: :layout
end

# Display todos for a single list
get "/lists/:list_id" do
  
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:list_id/edit" do 
  
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post "/lists/:list_id" do 
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name]  = list_name
    session[:success] = "The list name has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a list from the session :lists
post "/lists/:list_id/delete" do 
  @lists.delete_at(@list_id.to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a new todo to a list
post "/lists/:list_id/todos" do 
  text = params[:todo].strip
  
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo item from a list
post "/lists/:list_id/todos/:todo_id/delete" do 
  todo_id = params[:todo_id].to_i
  todo_name = @list[:todos][todo_id][:name]
  
  @list[:todos].delete_at(todo_id)
  session[:success] = "Todo \"#{todo_name}\" was deleted from #{@list[:name]}."

  redirect "/lists/#{@list_id}"
end

# Update the status of a todo
post "/lists/:list_id/todos/:todo_id" do
  todo_id = params[:todo_id].to_i

  is_completed = params[:completed] == 'true'
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos in a list complete
post "/lists/:list_id/complete_all" do
  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos for list \"#{@list[:name]}\" were marked complete."
  redirect "/lists/#{@list_id}"
end



