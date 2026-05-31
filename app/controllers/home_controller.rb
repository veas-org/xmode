class HomeController < ApplicationController
  def index
  end

  def product
    redirect_to_landing_or_root("/product")
  end

  def pricing
    redirect_to_landing_or_root("/pricing")
  end

  def open_source
  end

  def security
    redirect_to_landing_or_root("/security")
  end

  def privacy
    redirect_to_landing_or_root("/privacy")
  end

  def terms
    redirect_to_landing_or_root("/terms")
  end

  private

  def redirect_to_landing_or_root(path)
    if (target = landing_url(path))
      redirect_to target, allow_other_host: true
    else
      redirect_to root_path, notice: "Set LANDING_BASE_URL to enable the xmode commercial site."
    end
  end
end
