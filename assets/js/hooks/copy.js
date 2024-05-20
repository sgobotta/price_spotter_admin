export default {
  mounted() {
    let { to } = this.el.dataset;

    const handleClick = (event) => {
      event.preventDefault();
      let text = document.getElementById(to).value
      navigator.clipboard.writeText(text).then(() => {})
    }

    this.el.addEventListener("click", (event) => {
      handleClick(event)
    });

    this.el.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        handleClick(event)
      }
    })
  },
}
