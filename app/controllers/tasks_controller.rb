class TasksController < ApplicationController
  before_filter :authenticate_user!
  before_filter :find_task, :except => [:index, :create, :active_tasks, :completed_tasks, :task_requests]
  respond_to :html, :js

  def index
    @task = Task.new
    @tasks = Task.joins(:participants).
                  order('participants.priority desc').
                  where(participants:{status:'confirmed',user_id:current_user.id},completed:false).
                  paginate(:page => params[:page], :per_page => 7)
  end

  def show
    @users = User.all
    @participant = current_user.participants.find_by_task_id(params[:id])
    @participants = Participant.where(task_id:params[:id])
  end

  def edit
  end

  def create
   @tasks = Task.joins(:participants).
                 order('participants.priority desc').
                 where(participants:{status:'confirmed',user_id:current_user.id},completed:false)
   @task = current_user.tasks.new(task_params)
   @task.user_id = current_user.id

   #-- creating participant entry for task author and marking  status as confirmed
   if @task.save
     participations = Participant.where(user_id:current_user.id)

     if participations.count > 0
       last_priority = participations.last.priority.to_i
       priority = last_priority + 1
       @participant = Participant.create(user_id:current_user.id, task_id:@task.id, status:'confirmed', priority:priority)
     else
       @participant = Participant.create(user_id:current_user.id, task_id:@task.id, status:'confirmed', priority:1)
     end
   else
     flash.now[:notice] = "Task creation Unsuccessfull"
   end
  end

  def update
    @task.update_attributes(task_params)

    redirect_to task_path(@task.id)
  end

  def destroy
    @task.destroy
    respond_with(@task) do |format|
      format.html{redirect_to tasks_path}
    end
  end

  def confirm_delete
    @participant = current_user.participants.find_by_task_id(@task.id)
  end

  def active_tasks
    @tasks = Task.joins(:participants).
                  order('participants.priority desc').
                  where(participants:{status:'confirmed',user_id:current_user.id},completed:false).
                  paginate(:page => params[:page], :per_page => 7)
  end

  def completed_tasks
    @tasks = Task.joins(:participants).
                  order('participants.priority desc').
                  where(participants:{status:'confirmed',user_id:current_user.id},completed:true).
                  paginate(:page => params[:page], :per_page => 7)
  end

  def task_requests
    @participants  = Participant.where(status: "pending", user_id:current_user.id)
    @tasks = Task.all
  end

  def task_completion
    if @task.completed == false
      @task.completed = true
      @task.comments.create(user_name: current_user.name, comment:'Status changed to Done')
    else
      @task.completed = false
      @task.comments.create(user_name: current_user.name, comment:'Status changed to UnDone',commenter:current_user.id)
    end

    if @task.save
      respond_with(@task) do |format|
        format.html{redirect_to task_path(params[:id])}
      end
    else
      redirect_to task_path @task, flash: { error:"Task completion error" }
    end

  end

  def add_participants
    @users = User.all
    @participant = Participant.new
  end

  def task_up
    @participant = current_user.participants.find_by_task_id(params[:id])
    priority = @participant.priority
    if @task.completed == true
      @other_participant = current_user.participants.joins(:task).
                          where("participants.priority > ? AND tasks.completed = ?",priority, true).
                          order('priority DESC').last
    else
      @other_participant = current_user.participants.joins(:task).
                          where("participants.priority > ? AND tasks.completed = ?",priority, false).
                          order('priority DESC').last
    end

    swap(@participant, @other_participant)
  end

  def task_down
    @participant = current_user.participants.find_by_task_id(params[:id])
    priority = @participant.priority
    if @task.completed == true
      @other_participant = current_user.participants.joins(:task).
                           where("participants.priority < ? AND tasks.completed = ?",priority, true).
                           order('priority DESC').first
    else
      @other_participant = current_user.participants.joins(:task).
                           where("participants.priority < ? AND tasks.completed = ?",priority, false).
                           order('priority DESC').first
    end
    swap(@participant, @other_participant)
  end


  private

  def swap(first, second)### swaps priority of two participants
    first.priority, second.priority = second.priority, first.priority
    first.save!
    second.save!
  end

  def find_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description)
  end


end
