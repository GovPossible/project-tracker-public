import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "preview", "textarea"]
  static values = {
    cloudName: String,
    uploadPreset: String
  }

  connect() {
    this.urls = []
  }

  paste(event) {
    const items = event.clipboardData?.items
    if (!items) return

    for (const item of items) {
      if (item.type.startsWith("image/")) {
        event.preventDefault()
        this.uploadFile(item.getAsFile())
        return
      }
    }
  }

  selectFile() {
    this.fileInputTarget.click()
  }

  fileSelected(event) {
    const file = event.target.files[0]
    if (file) this.uploadFile(file)
    event.target.value = ""
  }

  async uploadFile(file) {
    const placeholder = this.addPlaceholder()

    const formData = new FormData()
    formData.append("file", file)
    formData.append("upload_preset", this.uploadPresetValue)

    try {
      const response = await fetch(
        `https://api.cloudinary.com/v1_1/${this.cloudNameValue}/image/upload`,
        { method: "POST", body: formData }
      )

      if (!response.ok) throw new Error("Upload failed")

      const data = await response.json()
      this.urls.push(data.secure_url)
      this.replacePlaceholder(placeholder, data.secure_url)
      this.syncHiddenInputs()
      this.updateTextareaRequired()
    } catch (error) {
      placeholder.remove()
      alert("Image upload failed. Please try again.")
    }
  }

  addPlaceholder() {
    const div = document.createElement("div")
    div.className = "inline-flex items-center gap-1 p-2 border rounded bg-gray-50 text-xs text-gray-500"
    div.textContent = "Uploading..."
    this.previewTarget.appendChild(div)
    return div
  }

  replacePlaceholder(placeholder, url) {
    const thumb = this.buildThumbnail(url)
    placeholder.replaceWith(thumb)
  }

  buildThumbnail(url) {
    const wrapper = document.createElement("div")
    wrapper.className = "relative inline-block"

    const thumbUrl = url.replace("/upload/", "/upload/c_limit,h_200,w_200/")

    const link = document.createElement("a")
    link.href = url
    link.target = "_blank"
    link.rel = "noopener"

    const img = document.createElement("img")
    img.src = thumbUrl
    img.className = "h-20 rounded border"
    img.alt = "Uploaded image"

    link.appendChild(img)
    wrapper.appendChild(link)

    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.className = "absolute -top-1 -right-1 bg-red-500 text-white rounded-full w-5 h-5 text-xs flex items-center justify-center hover:bg-red-600 cursor-pointer"
    removeBtn.textContent = "\u00d7"
    removeBtn.addEventListener("click", () => {
      this.urls = this.urls.filter(u => u !== url)
      wrapper.remove()
      this.syncHiddenInputs()
      this.updateTextareaRequired()
    })
    wrapper.appendChild(removeBtn)

    return wrapper
  }

  syncHiddenInputs() {
    this.previewTarget.querySelectorAll("input[name='image_urls[]']").forEach(el => el.remove())

    this.urls.forEach(url => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "image_urls[]"
      input.value = url
      this.previewTarget.appendChild(input)
    })
  }

  updateTextareaRequired() {
    if (this.hasTextareaTarget) {
      this.textareaTarget.required = this.urls.length === 0
    }
  }
}
