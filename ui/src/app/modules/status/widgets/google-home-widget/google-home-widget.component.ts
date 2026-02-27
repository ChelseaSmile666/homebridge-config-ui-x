import { Component, inject, Input, OnInit } from '@angular/core'
import { Router } from '@angular/router'
import { TranslatePipe } from '@ngx-translate/core'
import { firstValueFrom, Subject } from 'rxjs'

import { ApiService } from '@/app/core/api.service'
import { ManagePluginsService } from '@/app/core/manage-plugins/manage-plugins.service'
import { Plugin } from '@/app/core/manage-plugins/manage-plugins.interfaces'

@Component({
  templateUrl: './google-home-widget.component.html',
  standalone: true,
  imports: [
    TranslatePipe,
  ],
})
export class GoogleHomeWidgetComponent implements OnInit {
  private $api = inject(ApiService)
  private $plugin = inject(ManagePluginsService)
  private $router = inject(Router)

  @Input() resizeEvent: Subject<any>

  public loading = true
  public isInstalled = false
  public isLinked = false
  public pluginName = 'homebridge-gsh'
  private pluginRef: Plugin | null = null

  public async ngOnInit() {
    await this.checkPluginStatus()
  }

  private async checkPluginStatus() {
    try {
      const plugins: Plugin[] = await firstValueFrom(this.$api.get('/plugins'))
      const gsh = plugins.find((p: Plugin) => p.name === this.pluginName)
      this.isInstalled = !!gsh
      this.pluginRef = gsh || null

      if (this.isInstalled) {
        await this.checkLinkedStatus()
      }
    } catch {
      this.isInstalled = false
    } finally {
      this.loading = false
    }
  }

  private async checkLinkedStatus() {
    try {
      const config: any[] = await firstValueFrom(this.$api.get(`/config-editor/plugin/${this.pluginName}`))
      const gshConfig = config?.[0]
      this.isLinked = !!(gshConfig?.token)
    } catch {
      this.isLinked = false
    }
  }

  public openSettings() {
    if (this.isInstalled && this.pluginRef) {
      void this.$plugin.settings(this.pluginRef)
    } else {
      void this.$router.navigate(['/plugins'], { queryParams: { search: this.pluginName } })
    }
  }
}
