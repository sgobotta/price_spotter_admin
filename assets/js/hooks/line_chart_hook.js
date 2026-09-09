import RealtimeLineChart from '../charts/line_chart'

export default {
  destroyed() {
    this.chart.destroy()
  },
  mounted() {
    this.chart = new RealtimeLineChart(this.el)

    this.handleEvent('set-chart-data', ({
      labels,
      datasets,
      timezone
    }) => {
      this.chart.setData(labels, datasets, timezone)
    })
  }
}
