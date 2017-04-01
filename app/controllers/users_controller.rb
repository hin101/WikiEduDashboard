# frozen_string_literal: true
require "#{Rails.root}/lib/wiki_course_edits"
require "#{Rails.root}/lib/importers/user_importer"
require "#{Rails.root}/app/workers/remove_assignment_worker"
require "#{Rails.root}/app/workers/update_course_worker"

#= Controller for user functionality
class UsersController < ApplicationController
  respond_to :html, :json

  before_action :require_participating_user, only: [:enroll]
  before_action :require_signed_in, only: [:update_locale]
  before_action :require_admin_permissions, only: [:index]

  layout 'admin', only: [:index]

  def signout
    if current_user.nil?
      redirect_to '/'
    else
      current_user.update_attributes(wiki_token: nil, wiki_secret: nil)
      redirect_to true_destroy_user_session_path
    end
  end

  def update_locale
    locale = params[:locale]

    unless I18n.available_locales.include?(locale.to_sym)
      render json: { message: 'Invalid locale' }, status: :unprocessable_entity
      return
    end

    current_user.locale = locale
    current_user.save!
    render json: { success: true }
  end

  #########################
  # Enrollment management #
  #########################

  # This method is for one user, such as an instructor or admin, to add another
  # user to a course. Students joining a course themselves are handled via
  # SelfEnrollmentController.
  def enroll
    if request.post?
      add
    elsif request.delete?
      remove
    end
  end

  ####################################################
  # User listing page for Admins                     #
  ####################################################
  def index
    @users = if params[:email].present?
               User.search_by_email(params[:email])
             else
               User.instructor.limit(20)
                   .order(created_at: :desc)
             end
  end

  private

  #################
  # Adding a user #
  #################
  def add
    set_course_and_user
    ensure_user_exists { return }
    @result = JoinCourse.new(course: @course, user: @user, role: enroll_params[:role]).result
    ensure_enrollment_success { return }

    UpdateCourseWorker.schedule_edits(course: @course, editing_user: current_user)
    make_enrollment_edits
    render 'users', formats: :json
  end

  def ensure_user_exists
    return unless @user.nil?
    username = enroll_params[:user_id] || enroll_params[:username]
    render json: { message: I18n.t('courses.error.user_exists', username: username) },
           status: 404
    yield
  end

  def ensure_enrollment_success
    return unless @result[:failure]
    render json: { message: @result[:failure] }, status: 404
    yield
  end

  def make_enrollment_edits
    return unless enroll_params[:role].to_i == CoursesUsers::Roles::STUDENT_ROLE
    # for students only, posts templates to userpage and sandbox
    EnrollInCourseWorker.schedule_edits(course: @course,
                                        editing_user: current_user,
                                        enrolling_user: @user)
  end

  ###################
  # Removing a user #
  ###################
  def remove
    set_course_and_user
    return if @user.nil?

    @course_user = CoursesUsers.find_by(user_id: @user.id,
                                        course_id: @course.id,
                                        role: enroll_params[:role])
    return if @course_user.nil? # This will happen if the user was already removed.

    remove_assignment_templates
    @course_user.destroy # destroying the course_user also destroys associated Assignments.

    render 'users', formats: :json
    UpdateCourseWorker.schedule_edits(course: @course, editing_user: current_user)
  end

  # If the user has Assignments, update article talk pages to remove them from
  # the assignment templates.
  def remove_assignment_templates
    assignments = @course_user.assignments
    assignments.each do |assignment|
      RemoveAssignmentWorker.schedule_edits(course: @course, editing_user: current_user, assignment: assignment)
    end
  end

  ##################
  # Finding a user #
  ##################
  def set_course_and_user
    @course = Course.find_by_slug(params[:id])
    if enroll_params.key? :user_id
      @user = User.find(enroll_params[:user_id])
    elsif enroll_params.key? :username
      find_or_import_user_by_username
    end
  end

  def find_or_import_user_by_username
    username = enroll_params[:username]
    @user = User.find_by(username: username)
    @user = UserImporter.new_from_username(username) if @user.nil?
  end

  def enroll_params
    params.require(:user).permit(:user_id, :username, :role)
  end
end
