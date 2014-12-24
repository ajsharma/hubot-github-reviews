# Description:
#   Show who is reviewing a pull request
#
# Dependencies:
#   "githubot": "0.4.x"
#   "util": ""
#
# Configuration:
#   HUBOT_GITHUB_TOKEN = get by running `curl -u <username> https://api.github.com/user`
#   HUBOT_GITHUB_USER
#   HUBOT_GITHUB_API
#   HUBOT_GITHUB_ORG
#
# Github Comment Commands:
#   /reviewing
#   /reviewed
#   /needswork
#
# Commands:
#
# Notes:
#
# Author:
#   ajsharma

util = require 'util'

module.exports = (robot) ->

  github = require("githubot")(robot)

  unless (url_api_base = process.env.HUBOT_GITHUB_API)?
    url_api_base = "https://api.github.com"

  addGithubStateToPullRequest = ( repository, pullNumber, user, state, description ) ->
    url = "#{url_api_base}/repos/#{repository}/pulls/#{pullNumber}/commits"
    console.log "getting: #{url}"
    github.get url, (commits) ->
      console.log "get response: #{util.inspect commits}"
      # Get the latest commit
      commit = commits[commits.length - 1]

      # Set status on the build
      url = "#{url_api_base}/repos/#{repository}/statuses/#{commit.sha}"
      data = {
        context: "#{user}/review"
        description: description
        state: state # pending, success, error, failure
      }
      console.log "posting: #{url} with data: #{util.inspect data}"
      github.post url, data, ( commit ) ->
        console.log "post response: #{util.inspect commit}"

  startReview = ( repository, pullNumber, user ) ->
    console.log "#{user} is reviewing #{repository}/#{pullNumber}"
    addGithubStateToPullRequest repository, pullNumber, user, "pending", "#{user} is reviewing"

  completeReview = ( repository, pullNumber, user ) ->
    console.log "#{user} has reviewed #{repository}/#{pullNumber}"
    addGithubStateToPullRequest repository, pullNumber, user, "success", "#{user} has finished reviewing"

  failReview = ( repository, pullNumber, user ) ->
    console.log "#{user} has failed #{repository}/#{pullNumber}"
    addGithubStateToPullRequest repository, pullNumber, user, "failure", "#{user} thinks more work is needed"

  # Handle GET requests
  robot.router.get "/hubot/github/pull_requests/comments", (req, res) ->
    res.send "Only POSTs allowed"

  # Handle POST requests
  robot.router.post "/hubot/github/pull_requests/comments", (req, res) ->
    console.log "Received github issue comment: #{util.inspect req.body, 5}"

    githubCommentAuthor = req.body.comment.user.login
    githubCommentBody   = req.body.comment.body.trim()
    githubPullNumber    = req.body.issue?.number || req.body.pull_request?.number
    githubRepository    = req.body.repository.full_name

    if githubCommentBody.match( /^\/reviewing/i )?
      startReview githubRepository, githubPullNumber, githubCommentAuthor
    else if githubCommentBody.match( /^\/reviewed/i )?
      completeReview githubRepository, githubPullNumber, githubCommentAuthor
    else if githubCommentBody.match( /^\/needsWork/i )?
      failReview githubRepository, githubPullNumber, githubCommentAuthor

    res.send "Done"
