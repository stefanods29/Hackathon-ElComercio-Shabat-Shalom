import { Inject, Injectable } from '@nestjs/common';
import { ZONE_REPOSITORY, type ZoneRepository, type ZoneSummary } from './ports.js';

@Injectable()
export class ListZones {
  constructor(@Inject(ZONE_REPOSITORY) private readonly zones: ZoneRepository) {}

  execute(): Promise<ZoneSummary[]> {
    return this.zones.list();
  }
}
