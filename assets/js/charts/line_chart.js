// assets/js/line_chart.js

// https://www.chartjs.org/docs/3.6.1/getting-started/integration.html#bundlers-webpack-rollup-etc
import Chart from 'chart.js/auto'

// A wrapper of Chart.js that configures the realtime line chart.
export default class {
  constructor(ctx) {
    const self = this
    const config = {
      type: 'line',
      data: {datasets: [], labels: []},
      options: {
        responsive: true,
        maintainAspectRatio: false,
        resizeDelay: 0,
        spanGaps: true,
        parsing: false,
        scales: {
          x: {
            type: 'linear',
            ticks: {
              maxTicksLimit: 8,
              callback: function (value) {
                return self._formatTimestamp(value, self.timeZone)
              }
            }
          },
          y: {
            suggestedMax: 50000,
            suggestedMin: 500
          }
        },
        plugins: {
          tooltip: {
            callbacks: {
              title: function (items) {
                if (items.length === 0) {
                  return ''
                }

                const raw = items[0].raw
                if (raw != null && raw.formatted_x != null) {
                  return raw.formatted_x
                }

                return self._formatTimestamp(items[0].parsed.x, self.timeZone)
              }
            }
          }
        }
      }
    }

    this.timeZone = 'UTC'
    this.chart = new Chart(ctx, config)
  }

  setData(labels, datasets, timeZone) {
    this.timeZone = timeZone == null ? 'UTC' : timeZone
    this.chart.config.data.labels = labels
    this.chart.config.data.datasets = datasets.map((dataset) => {
      return Object.assign({}, dataset, {
        backgroundColor: dataset.background_color,
        borderColor: dataset.border_color,
        fill: false,
        tension: 0.09,
        pointRadius: 3,
        pointHoverRadius: 5
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
      .map((value) => {
        if (value != null && typeof value === 'object') {
          return parseFloat(value.y)
        }

        return parseFloat(value)
      })
      .filter((value) => !Number.isNaN(value))
  }

  _formatTimestamp(ms, timeZone) {
    const tz = timeZone == null ? 'UTC' : timeZone
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: tz,
      day: 'numeric',
      month: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }).formatToParts(new Date(ms))

    const byType = {}
    for (let i = 0; i < parts.length; i++) {
      byType[parts[i].type] = parts[i].value
    }

    return (
      byType.day +
      '/' +
      byType.month +
      '/' +
      byType.year +
      ' - ' +
      byType.hour +
      ':' +
      byType.minute +
      'hs'
    )
  }
}
