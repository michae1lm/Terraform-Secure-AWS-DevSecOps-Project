output "detector_id" {
  value = var.enabled ? aws_guardduty_detector.main[0].id : null
}
