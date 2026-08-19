require "sinatra/base"
require "sinatra/json"
require "sequel"
require "securerandom"
require "dotenv/load"

DB = Sequel.connect(ENV.fetch("DATABASE_URL"))
DB.extension :pg_json
require_relative "models/resource"

class ResourceApi < Sinatra::Base
  configure do
    set :show_exceptions, false
  end

  before do
    content_type :json
  end

  # Create or update (upsert) a resource
  post "/resources" do
    payload = JSON.parse(request.body.read)
    now = Time.now

    DB[:resources]
      .insert_conflict(
        target: [:session_id, :resource_type, :resource_id],
        update: {
          resource: Sequel[:excluded][:resource],
          expired_at: Sequel[:excluded][:expired_at],
          updated_at: now
        }
      )
      .insert(
        id: SecureRandom.uuid,
        session_id: payload.fetch("sessionId"),
        resource_type: payload.fetch("resourceType"),
        resource_id: payload.fetch("resourceId"),
        resource: Sequel.pg_jsonb(payload.fetch("resource")),
        created_at: now,
        updated_at: now,
        expired_at: payload.fetch("expiredAt")
      )

    record = Resource.first(
      session_id: payload["sessionId"],
      resource_type: payload["resourceType"],
      resource_id: payload["resourceId"]
    )

    status record.created_at == record.updated_at ? 201 : 200
    json(to_response(record))
  rescue KeyError => e
    status 422
    json(error: "Missing field: #{e.key}")
  end

  # Fetch a single resource
  get "/:session_id/:resource_type/:resource_id" do
    record = Resource.first(
      session_id: params[:session_id],
      resource_type: params[:resource_type],
      resource_id: params[:resource_id]
    )

    halt 404 if record.nil?
    halt 404 if record.expired?

    json(to_response(record))
  end

  # Expire every resource in a session
  delete "/sessions/:session_id" do
    now = Time.now

    updated_count = DB[:resources]
      .where(session_id: params[:session_id])
      .where { expired_at > now }
      .update(expired_at: now, updated_at: now)

    status 200
    json(sessionId: params[:session_id], expiredCount: updated_count)
  end

  private

  def to_response(record)
    {
      id: record.id,
      sessionId: record.session_id,
      resourceType: record.resource_type,
      resourceId: record.resource_id,
      resource: record.resource,
      createdAt: record.created_at,
      updatedAt: record.updated_at,
      expiredAt: record.expired_at
    }
  end
end
