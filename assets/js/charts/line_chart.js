// assets/js/line_chart.js

// https://www.chartjs.org/docs/3.6.1/getting-started/integration.html#bundlers-webpack-rollup-etc
import Chart from 'chart.js/auto'

// A wrapper of Chart.js that configures the realtime line chart.
export default class {
  constructor(ctx) {
    const config = {
      type: 'line',
      data: {datasets: [], labels: []},
      options: {
        responsive: true,
        maintainAspectRatio: false,
        resizeDelay: 0,
        spanGaps: false,
        scales: {
          x: {},
          y: {
            suggestedMax: 50000,
            suggestedMin: 500
          }
        }
      }
    }

    this.chart = new Chart(ctx, config)
  }

  setData(labels, datasets) {
    this.chart.config.data.labels = labels
    this.chart.config.data.datasets = datasets.map((dataset) => {
      return Object.assign({}, dataset, {
        backgroundColor: dataset.background_color,
        borderColor: dataset.border_color,
        fill: false,
        tension: 0.09
      })
    })

    const numericValues = this._extractNumericValues(datasets)

    if (numericValues.length > 0) {
      const suggestedMin = Math.min(...numericValues)
      const suggestedMax = Math.max(...numericValues)
      this.chart.config.options.scales.y.suggestedMin = suggestedMin - 500
      this.chart.config.options.scales.y.suggestedMax = suggestedMax + 500
    }

    this.chart.update()
    this.chart.resize()
  }

  destroy() {
    this.chart.destroy()
  }

  _extractNumericValues(datasets) {
    return datasets
      .reduce((acc, dataset) => {
        return acc.concat(dataset.data)
      }, [])
      .filter((value) => value !== null && value !== undefined)
      .map((value) => parseFloat(value))
      .filter((value) => !Number.isNaN(value))
  }
}
