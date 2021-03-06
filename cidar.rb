require 'open-uri'
require 'sinatra'
require 'json'

URL = 'http://ci.lhotse.ov.otto.de:8080/view/'

get '/p13n' do
  erb :p13n
end

helpers do
  def status_for(project)
    @info = Info.new(project)
    erb 'status <%= @info.status %>'
  end
end

class Info
  def initialize(project)
    @project = project
    @view = JSON.parse(open(URL + project + '/api/json').read)
  end

  def name
    @view['name']
  end

  def description
    @view['description']
  end

  def jobs
    @view['jobs'].collect { |job| Job.new(job['url']) }
  end

  def success?
    jobs.inject(true) { |result, job| result && job.success? }
  end

  def building?
    jobs.inject(false) { |result, job| result || job.building? }
  end

  def status
    building? ? "building" : (success? ? "success" : "failure")
  end

  def commiters
    jobs.inject([]) { |result, job| result += job.commiters}.uniq
  end

end

class Job
  def initialize(url)
    @job = JSON.parse(open(url + '/api/json').read)
    @detail = JSON.parse(open(url + '/lastBuild/api/json').read)
  end

  def name
    @job['name']
  end

  def health
    stability = @job['healthReport'].select { |entry| entry ['description'] =~ /Build stability/ }
    stability && stability.last()['score']
  end

  def buildLabel
    buildNumber = @job['lastBuild'] && @job['lastBuild']['number']
    '#' + buildNumber.to_s + ' ' + (commiter_names_obfuscated() && commiter_names_obfuscated().first()).to_s
  end

  def status?
    "status " + (building? ? "building" : (success? ? "success" : "failure"))
  end

  def success?
    @detail['result'] == "SUCCESS"
  end

  def building?
    @detail['building']
  end

  def commit_message
    if (!@detail['changeSet']['items'].empty?)
      @detail['changeSet']['items'].last()['comment']
    end
  end

  def commit_time(fmt)
    if (!@detail['changeSet']['items'].empty?)
      time = Time.parse(@detail['changeSet']['items'].last()['date']).strftime(fmt)
      time ? "@ " + time.to_s : ""
    end
  end

  def commiters
    knownNames = commiter_names & knownPeople
    if (!(commiter_names - knownNames).empty?)
      knownNames << "unknown"
    end
    knownNames
  end

  private

  def commiter_names_obfuscated()
    commiter_names.collect{|name| name.split(" ").collect{|piece| piece[0] + "*" * (piece.length - 1) }.join(" ") }
  end

  def commiter_names()
    @detail['changeSet']['items'].collect { |commit| commit['author']['fullName'] }.uniq
  end

  def knownPeople()
    get_all_image_file_names() - ['unknown']
  end

  def get_all_image_file_names()
    images = []
    Dir.entries('public/images').each { |image| images << image[0..-5] }
    images
  end

end
