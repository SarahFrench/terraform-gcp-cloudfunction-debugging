provider "google-beta" {
  project = var.project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

locals {
  random_string    = "ajshdgaj"
  trigger-location = "us-central1"
  zip_path         = "../test-fixtures/zip-made-by-tf-config.zip"

  # JS version
  source-index          = "../test-fixtures/function-source-eventarc-gcs/index.js"
  source-dependencies   = "../test-fixtures/function-source-eventarc-gcs/package.json"
  index-filename        = "index.js"
  dependencies-filename = "package.json"
  entrypoint            = "entryPoint"
  runtime               = "nodejs12"
}

data "archive_file" "cloud-function" {
  type        = "zip"
  output_path = local.zip_path
  source {
    content  = file(local.source-index)
    filename = local.index-filename
  }
  source {
    content  = file(local.source-dependencies)
    filename = local.dependencies-filename
  }
}

resource "google_service_account" "account" {
  provider     = google-beta
  account_id   = "s-a-${local.random_string}"
  display_name = "Test Service Account"
}

resource "google_project_iam_member" "invoking" {
  provider = google-beta
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.account.email}"
}

resource "google_project_iam_member" "event-receiving" {
  provider = google-beta
  project  = var.project_id
  role     = "roles/eventarc.eventReceiver"
  member   = "serviceAccount:${google_service_account.account.email}"
}

resource "google_storage_bucket" "function-bucket" {
  provider                    = google-beta
  name                        = "cloudfunctions2-function-bucket-${local.random_string}" # Every bucket name must be globally unique
  location                    = "US"
  uniform_bucket_level_access = true
  force_destroy               = true

}

resource "google_storage_bucket_object" "object" {
  provider = google-beta
  name     = "cloud-function-${data.archive_file.cloud-function.output_sha}.zip"
  bucket   = google_storage_bucket.function-bucket.name
  source   = local.zip_path # Path to the zipped function source code
}

resource "google_storage_bucket" "trigger-bucket" {
  provider                    = google-beta
  name                        = "cloudfunctions2-trigger-bucket-${local.random_string}" # Every bucket name must be globally unique
  location                    = "us-central1"                                           # Must match trigger location
  uniform_bucket_level_access = true
  force_destroy               = true
}

// Enable notifications by giving the correct IAM permission to the unique service account.

data "google_storage_project_service_account" "gcs_account" {
  provider = google-beta
}

# Set permissions on topic itself but then got this response error message from API:
# To use GCS CloudEvent triggers, the GCS service account requires the Pub/Sub Publisher (roles/pubsub.publisher) IAM role in the specified project. (See https://cloud.google.com/eventarc/docs/run/quickstart-storage#before-you-begin)
resource "google_project_iam_member" "gcs-pubsub-publishing" {
  provider = google-beta
  project  = var.project_id
  role     = "roles/pubsub.publisher"
  member   = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

resource "google_cloudfunctions2_function" "test" {
  provider    = google-beta
  name        = "test-function-${local.random_string}"
  location    = "us-central1"
  description = "A new function that is triggered by new files being added to a bucket"

  build_config {
    runtime     = local.runtime
    entry_point = local.entrypoint # Set the entry point 
    environment_variables = {
      BUILD_CONFIG_TEST = "build_test"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.function-bucket.name
        object = google_storage_bucket_object.object.name
      }
    }
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    environment_variables = {
      SERVICE_CONFIG_TEST = "config_test"
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.account.email
  }

  event_trigger {
    trigger_region        = local.trigger-location
    event_type            = "google.cloud.storage.object.v1.finalized"
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.account.email
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.trigger-bucket.name
    }
  }
}