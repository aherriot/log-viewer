import { Controller } from "@hotwired/stimulus"

// Debounces text/number input before auto-submitting the enclosing form,
// but submits immediately on select/date changes (discrete choices don't
// need debouncing the way free-typed text does).
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  submit() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }

  submitDebounced() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
}
