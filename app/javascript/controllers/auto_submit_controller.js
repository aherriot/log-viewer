import { Controller } from "@hotwired/stimulus"

// Debounces text/number input before auto-submitting the enclosing form,
// but submits immediately on select/date changes (discrete choices don't
// need debouncing the way free-typed text does). Also toggles a "loading"
// class on the form while a Turbo-driven submission is in flight.
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  connect() {
    this.element.addEventListener("turbo:submit-start", this.showLoading)
    this.element.addEventListener("turbo:submit-end", this.hideLoading)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.showLoading)
    this.element.removeEventListener("turbo:submit-end", this.hideLoading)
  }

  showLoading = () => this.element.classList.add("loading")
  hideLoading = () => this.element.classList.remove("loading")

  submit() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }

  submitDebounced() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
}
