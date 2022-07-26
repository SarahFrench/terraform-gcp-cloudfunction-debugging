provider "google-beta" {
  project = var.project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

locals {
  random_string = "svcowmnm"
}

# APIs need to be activated before resources can be created
resource "google_project_service" "iam" {
  provider = google-beta
  project  = var.project_id
  service  = "iam.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "cloudfunctions" {
  provider = google-beta
  project  = var.project_id
  service  = "cloudfunctions.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "eventarc" {
  provider = google-beta
  project  = var.project_id
  service  = "eventarc.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "run" {
  provider = google-beta
  project  = var.project_id
  service  = "run.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "artifactregistry" {
  provider = google-beta
  project  = var.project_id
  service  = "artifactregistry.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "cloudbuild" {
  provider = google-beta
  project  = var.project_id
  service  = "cloudbuild.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "pubsub" {
  provider = google-beta
  project  = var.project_id
  service  = "pubsub.googleapis.com"

  disable_dependent_services = true
}

#### UNCOMMENT and apply in 2nd step.
#### If you do a `terraform destroy` and redo an `apply` of this config you might have to do some imports...

# resource "google_service_account" "account" {
#   provider     = google-beta
#   project      = var.project_id
#   account_id   = "tf-test-sa-${local.random_string}"
#   display_name = "Test Service Account - used for both the cloud function and eventarc trigger in the test"
# }

# resource "google_storage_bucket" "source-bucket" {
#   provider                    = google-beta
#   project                     = var.project_id
#   name                        = "tf-test-source-bucket-${local.random_string}"
#   location                    = "US"
#   uniform_bucket_level_access = true
# }

# resource "google_storage_bucket_object" "object" {
#   provider = google-beta
#   name     = "function-source.zip"
#   bucket   = google_storage_bucket.source-bucket.name
#   # source   = "../test-fixtures/zip-not-made-by-terraform.zip" # This file causes a failure
#   source = "../test-fixtures/zip-made-by-tf-config.zip" # This file allows successful creation (apply API enablement first)
# }

# resource "google_storage_bucket" "trigger-bucket" {
#   provider                    = google-beta
#   project                     = var.project_id
#   name                        = "tf-test-trigger-bucket-${local.random_string}"
#   location                    = "us-central1" # The trigger must be in the same location as the bucket
#   uniform_bucket_level_access = true
# }

# data "google_storage_project_service_account" "gcs_account" {
#   provider = google-beta
#   project  = var.project_id
# }

# # To use GCS CloudEvent triggers, the GCS service account requires the Pub/Sub Publisher(roles/pubsub.publisher) IAM role in the specified project.
# # (See https://cloud.google.com/eventarc/docs/run/quickstart-storage#before-you-begin)
# resource "google_project_iam_member" "gcs-pubsub-publishing" {
#   provider = google-beta
#   project  = var.project_id # Required argument
#   role     = "roles/pubsub.publisher"
#   member   = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
# }

# # Permissions on the service account for the function and Eventarc trigger
# resource "google_project_iam_member" "invoking" {
#   provider = google-beta
#   project  = var.project_id # Required argument
#   role     = "roles/run.invoker"
#   member   = "serviceAccount:${google_service_account.account.email}"
# }

# resource "google_project_iam_member" "event-receiving" {
#   provider = google-beta
#   project  = var.project_id # Required argument
#   role     = "roles/eventarc.eventReceiver"
#   member   = "serviceAccount:${google_service_account.account.email}"
# }

# resource "google_project_iam_member" "artifactregistry-reader" {
#   provider = google-beta
#   project  = var.project_id # Required argument
#   role     = "roles/artifactregistry.reader"
#   member   = "serviceAccount:${google_service_account.account.email}"
# }

# resource "google_cloudfunctions2_function" "test" {
#   provider = google-beta
#   depends_on = [
#     google_project_iam_member.event-receiving,
#     google_project_iam_member.artifactregistry-reader,
#   ]
#   project     = var.project_id
#   name        = "tf-test-function-${local.random_string}"
#   location    = "us-central1"
#   description = "A new function that is triggered by new files being added to a bucket"

#   build_config {
#     runtime     = "nodejs12"
#     entry_point = "entryPoint" # Set the entry point 
#     environment_variables = {
#       BUILD_CONFIG_TEST = "build_test"
#     }
#     source {
#       storage_source {
#         bucket = google_storage_bucket.source-bucket.name
#         object = google_storage_bucket_object.object.name
#       }
#     }
#   }

#   service_config {
#     max_instance_count = 3
#     min_instance_count = 1
#     available_memory   = "256M"
#     timeout_seconds    = 60
#     environment_variables = {
#       SERVICE_CONFIG_TEST = "config_test"
#     }
#     ingress_settings               = "ALLOW_INTERNAL_ONLY"
#     all_traffic_on_latest_revision = true
#     service_account_email          = google_service_account.account.email
#   }

#   event_trigger {
#     trigger_region        = "us-central1" # The trigger must be in the same location as the bucket
#     event_type            = "google.cloud.storage.object.v1.finalized"
#     retry_policy          = "RETRY_POLICY_RETRY"
#     service_account_email = google_service_account.account.email
#     event_filters {
#       attribute = "bucket"
#       value     = google_storage_bucket.trigger-bucket.name
#     }
#   }
# }