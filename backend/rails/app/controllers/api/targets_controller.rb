# frozen_string_literal: true
module Api
  class TargetsController < BaseController
    before_action :load_targets

    def index
      q = params[:q].to_s.downcase
      filtered = @targets.select { |t| t[:name].downcase.include?(q) || t[:host].downcase.include?(q) }
      render json: paginate(filtered)
    end

    def create
      render json: { ok: true, id: (@targets.last[:id] + 1) }
    end

    def update
      render json: { ok: true }
    end

    def destroy
      render json: { ok: true }
    end

    def test_ssh
      # stub for single or batch
      body = request.request_parameters.presence || JSON.parse(request.raw_post) rescue {}
      if body["targets"].is_a?(Array)
        results = body["targets"].map { |t| { host: t["host"], ok: true, latencyMs: 42 } }
        summary = { success: results.count { |r| r[:ok] }, failed: results.count { |r| !r[:ok] } }
        render json: { ok: true, results:, summary: }
      else
        render json: { ok: true, latencyMs: 42 }
      end
    end

    def test_connection
      render json: { ok: true, latencyMs: 35 }
    end

    def fs
      path = params[:path].presence || "/opt/apps"
      now = Time.now
      render json: {
        ok: true,
        entries: [
          { name: ".", type: "directory", mtime: now },
          { name: "app.jar", type: "file", mtime: now - 3600 },
          { name: "logs", type: "directory", mtime: now - 7200 }
        ]
      }
    end

    def processes
      render json: [
        { pid: 1234, cmd: "java -jar app.jar", port: 8080, started_at: Time.now - 3600 },
        { pid: 5678, cmd: "nginx: worker", port: 80, started_at: Time.now - 7200 }
      ]
    end

    private

    def load_targets
      @targets ||= [
        { id: 1, name: "生产A", host: "192.168.1.10", sshUser: "root", sshPort: 22, env: "prod", hasPrivateKey: false, hasPassword: true, rootPath: "/opt/apps", authType: "password" },
        { id: 2, name: "预发B", host: "192.168.1.20", sshUser: "deploy", sshPort: 22, env: "staging", hasPrivateKey: true, hasPassword: false, rootPath: "/opt/apps", authType: "key" }
      ]
    end
  end
end