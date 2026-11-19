resource "aws_guardduty_detector" "main" {
  count                        = var.enabled ? 1 : 0
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# GuardDuty S3 data event monitoring. Optional features may have usage charges.
resource "aws_guardduty_detector_feature" "s3" {
  count       = var.enabled ? 1 : 0
  detector_id = aws_guardduty_detector.main[0].id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}
