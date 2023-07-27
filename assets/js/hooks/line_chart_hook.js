import RealtimeLineChart from '../charts/line_chart'

export default {
  mounted() {
    this.chart = new RealtimeLineChart(this.el)

    this.handleEvent('new-point', ({ background_color, border_color, data_label, label, value }) => {
      this.chart.addPoint(data_label, label, value, background_color, border_color)
    })
  },
  destroyed() {
    this.chart.destroy()
  }
}