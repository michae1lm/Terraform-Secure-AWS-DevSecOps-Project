# I still create a budget manually before deploying; this optional resource
# makes the budget reproducible when I provide an email. It is not a hard cap.
resource "aws_budgets_budget" "monthly_lab" {
  count        = var.budget_email == "" ? 0 : 1
  name         = "tfsec-lab-10-usd-monthly"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.budget_email]
  }
}
