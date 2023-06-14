import RealtimeLineChart from '../charts/line_chart'

export default {
  mounted() {
    this.chart = new RealtimeLineChart(this.el)

    this.handleEvent('new-point', ({ data_label, label, value }) => {
      this.chart.addPoint(data_label, label, value)
    })
  },
  destroyed() {
    this.chart.destroy()
  }
}