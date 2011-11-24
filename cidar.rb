require 'nokogiri'
require 'open-uri'
require 'sinatra' 
require 'json'

JENKINS_URL = 'http://ci.lhotse.ov.otto.de:8080/view/p13n/job/'

get '/' do
  erb :index
end

helpers do
  def status_of(project)
    summary = JSON.parse(open(JENKINS_URL + project + '/api/json').read)
    detail = JSON.parse(open(JENKINS_URL + project + '/lastBuild/api/json').read)
    @status = Status.new(summary, detail)
    erb 'status <%= if @status.success? then "success" else "failure" end %><%= " building" if @status.building? %>'
  end

end

class Status
  def initialize(summary, detail)
    @summary = summary
    @detail = detail
  end
  
  def success?
    @detail['result'] == "SUCCESS"
  end
  
  def building?
    @detail['building']
  end
  
  def buildLabel
    buildNumber = @summary['lastBuild'] && @summary['lastBuild']['number']
    '#' + buildNumber.to_s + ' ' + (commiter_names() && commiter_names().first()).to_s
  end
  
  def commit_message
    @detail['changeSet']['items'].last()['comment']
  end
  
  def commiters
    knownNames = commiter_names & knownPeople
    if (!(commiter_names - knownNames).empty?)
      knownNames << "unknown"
    end
    knownNames
  end

  def health
    stability = @summary['healthReport'].select {|entry| entry ['description'] =~ /Build stability/}
    stability && stability.last()['score']
  end

  private

  def commiter_names()
    @detail['changeSet']['items'].collect{|commit| commit['author']['fullName']}.uniq
  end

  def knownPeople()
    ['richard']
  end

end