# frozen_string_literal: true

class ElasticIndexingControlWorker
  include ApplicationWorker

  feature_category :global_search
  idempotent!

  def perform
    if Elastic::IndexingControl.non_cached_pause_indexing?
      raise 'elasticsearch_pause_indexing is enabled, worker can not proceed'
    end

    Elastic::IndexingControl.resume_processing!
  end
end
