export default {
  mounted() {
    let { to } = this.el.dataset;
    this.el.addEventListener("click", (ev) => {
      ev.preventDefault();
      let text = document.getElementById(to).value
      navigator.clipboard.writeText(text).then(() => {})
    });
  },
}
