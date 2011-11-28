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
    erb 'status <%= if @info.success? then "success" else "failure" end %><%= " building" if @info.building? %>'
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
    '#' + buildNumber.to_s + ' ' + (commiter_names() && commiter_names().first()).to_s
  end

  def status?
    'status' + (success? ? ' success' : ' failure ') + (building? ? ' building' : '')
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

  def commiters
    knownNames = commiter_names & knownPeople
    if (!(commiter_names - knownNames).empty?)
      knownNames << "unknown"
    end
    knownNames
  end

  private

  def commiter_names()
    @detail['changeSet']['items'].collect { |commit| commit['author']['fullName'] }.uniq
  end

  def knownPeople()
    ['richard', 'Fabian Koehler', 'Christian Stamm']
  end

end
