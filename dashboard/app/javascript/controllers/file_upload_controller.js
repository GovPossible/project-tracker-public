import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "preview"]
  static values = {
    cloudName: String,
    uploadPreset: String,
    existingUrls: { type: Array, default: [] }
  }

  connect() {
    this.urls = [...this.existingUrlsValue]
    this.urls.forEach(url => this.addFileEntry(url))
    this.syncHiddenInputs()
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
    const placeholder = document.createElement("div")
    placeholder.className = "flex items-center gap-2 p-2 border rounded bg-gray-50 text-xs text-gray-500"
    placeholder.textContent = `Uploading ${file.name}...`
    this.previewTarget.appendChild(placeholder)

    const formData = new FormData()
    formData.append("file", file)
    formData.append("upload_preset", this.uploadPresetValue)

    try {
      const response = await fetch(
        `https://api.cloudinary.com/v1_1/${this.cloudNameValue}/auto/upload`,
        { method: "POST", body: formData }
      )

      if (!response.ok) throw new Error("Upload failed")

      const data = await response.json()
      this.urls.push(data.secure_url)
      placeholder.remove()
      this.addFileEntry(data.secure_url)
      this.syncHiddenInputs()
    } catch (error) {
      placeholder.remove()
      alert("File upload failed. Please try again.")
    }
  }

  addFileEntry(url) {
    const wrapper = document.createElement("div")
    wrapper.className = "flex items-center gap-2 p-2 border rounded bg-gray-50 text-sm group"

    const filename = decodeURIComponent(url.split("/").pop())
    const isImage = /\.(png|jpe?g|gif|webp|svg)$/i.test(filename)

    if (isImage) {
      const img = document.createElement("img")
      img.src = url.replace("/upload/", "/upload/c_limit,h_40,w_40/")
      img.className = "h-10 w-10 rounded border object-cover"
      img.alt = filename
      wrapper.appendChild(img)
    }

    const link = document.createElement("a")
    link.href = url
    link.target = "_blank"
    link.rel = "noopener"
    link.className = "text-purple-700 hover:underline truncate flex-1 min-w-0"
    link.textContent = filename
    wrapper.appendChild(link)

    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.className = "text-red-500 hover:text-red-700 text-xs shrink-0 cursor-pointer"
    removeBtn.textContent = "Remove"
    removeBtn.addEventListener("click", () => {
      this.urls = this.urls.filter(u => u !== url)
      wrapper.remove()
      this.syncHiddenInputs()
    })
    wrapper.appendChild(removeBtn)

    this.previewTarget.appendChild(wrapper)
  }

  syncHiddenInputs() {
    this.previewTarget.querySelectorAll("input[name='project[file_urls][]']").forEach(el => el.remove())

    this.urls.forEach(url => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "project[file_urls][]"
      input.value = url
      this.previewTarget.appendChild(input)
    })
  }
}
