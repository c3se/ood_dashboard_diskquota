require 'etc'
class DiskQuotaController < ApplicationController
  include ActionController::Live
  # GET /support?session_id=<session_UUID>
  # session_id [UUID] optional session to add data to the support ticket
  def index
    dq = DiskQuota.new()
    @res_list = dq.disk_quota
    respond_to do |format|
      format.html do
        render :index
      end
    end
  end
end
