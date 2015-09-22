React         = require 'react'
Modal         = require '../common/modal'

CourseStore        = require '../../stores/course_store'
ValidationStore    = require '../../stores/validation_store'
ValidationActions  = require '../../actions/validation_actions'

CourseActions = require '../../actions/course_actions'
ServerActions = require '../../actions/server_actions'

TextInput     = require '../common/text_input'
TextAreaInput = require '../common/text_area_input'
Calendar      = require '../common/calendar'

getState = ->
  course: CourseStore.getCourse()
  error_message: ValidationStore.firstMessage()

CourseClonedModal = React.createClass(
  displayName: 'CourseClonedModal'
  mixins: [CourseStore.mixin, ValidationStore.mixin]
  storeDidChange: ->
    @setState getState()
    @state.tempCourseId = @generateTempId()
    @handleCourse()
  getInitialState: ->
    getState()
  updateCourse: (value_key, value) ->
    to_pass = $.extend(true, {}, @state.course)
    to_pass[value_key] = value
    CourseActions.updateCourse to_pass
    if value_key in ['title', 'school', 'term']
      ValidationActions.setValid 'exists'
    @setState valuesUpdated: true
  slugify: (text) ->
    return text.replace " ", "_"
  generateTempId: ->
    title = if @state.course.title? then @slugify @state.course.title else ''
    school = if @state.course.school? then @slugify @state.course.school else ''
    term = if @state.course.term? then @slugify @state.course.term else ''
    return "#{school}/#{title}_(#{term})"
  saveCourse: ->
    if ValidationStore.isValid()
      @setState isSubmitting: true
      ValidationActions.setInvalid 'exists', 'This course is being checked for uniqueness', true
      ServerActions.checkCourse('exists', @generateTempId())
  isNewCourse: (course) ->
    # it's "new" if it was updated fewer than 10 seconds ago.
    updated = new Date(course.updated_at)
    ((Date.now() - updated) / 1000) < 10
  handleCourse: ->
    return unless @state.isSubmitting
    if @isNewCourse(@state.course)
      return window.location = "/courses/#{@state.course.slug}"
    if ValidationStore.isValid()
      ServerActions.updateClone($.extend(true, {}, { course: @state.course }), @state.course.slug)
    else if !ValidationStore.getValidation('exists').valid
      @setState isSubmitting: false, attemptedToSaveExistingCourse: true
      window.scrollTop()
  render: ->
    buttonClass = 'button dark'
    buttonClass += if @state.isSubmitting then ' working' else ''
    slug = @state.course.slug
    [school, title] = slug.split('/')

    errorMessage = if @state.error_message then (
      <div className='warning'>{@state.error_message}</div>
    )

    <Modal>
      <div className='wizard__panel active cloned-course'>
        <h3>Course Successfully Cloned</h3>
        <p>Your course has been cloned, including the elements of the timeline. Has anything else about your course changed? Feel free to update it now.</p>
        {errorMessage}
        <div className='wizard__form'>
          <div className='column'>
            <TextInput
              id='course_title'
              onChange={@updateCourse}
              value={@props.course.title}
              value_key='title'
              required=true
              validation={/^[\w\-\s\,\']+$/}
              editable=true
              label='Course title'
              placeholder='Title'
            />

            <TextInput
              id='course_term'
              onChange={@updateCourse}
              value={@props.course.term}
              value_key='term'
              required=true
              validation={/^[\w\-\s\,\']+$/}
              editable=true
              label='Course term'
              placeholder='Term'
            />

            <TextInput
              id='course_subject'
              onChange={@updateCourse}
              value={@props.course.subject}
              value_key='subject'
              editable=true
              label='Course subject'
              placeholder='Subject'
            />
            <TextInput
              id='course_expected_students'
              onChange={@updateCourse}
              value={@props.course.expected_students}
              value_key='expected_students'
              editable=true
              type='number'
              label='Expected number of students'
              placeholder='Expected number of students'
            />
            <TextAreaInput
              id='course_description'
              onChange={@updateCourse}
              value={@props.course.description}
              value_key='description'
              editable=true
              label='Course description'
              autoExpand=false
            />
            <TextInput
              id='course_start'
              onChange={@updateCourse}
              value={if @state.valuesUpdated then @props.course.start else null}
              value_key='start'
              required=true
              editable=true
              type='date'
              label='Start date'
              placeholder='Start date (YYYY-MM-DD)'
              blank=true
              isClearable=false
            />
            <TextInput
              id='course_end'
              onChange={@updateCourse}
              value={if @state.valuesUpdated then @props.course.end else null}
              value_key='end'
              required=true
              editable=true
              type='date'
              label='End date'
              placeholder='End date (YYYY-MM-DD)'
              blank=true
              date_props={minDate: moment(@props.course.start).add(1, 'week')}
              enabled={@props.course.start?}
              isClearable=false
            />

          </div>

          <div className='column'>
            <Calendar course={@props.course}
              editable=true
              setAnyDatesSelected={@setAnyDatesSelected}
              setBlackoutDatesSelected={@setBlackoutDatesSelected}
              shouldShowSteps=false
            />
            <label> I have no class holidays
              <input type='checkbox' onChange={@setNoBlackoutDatesChecked} ref='noDates' />
            </label>

          </div>
          <button onClick={@saveCourse} className={buttonClass}>Save New Course</button>
        </div>
      </div>
    </Modal>
)

module.exports = CourseClonedModal