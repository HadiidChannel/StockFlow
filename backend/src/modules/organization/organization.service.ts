import { prisma } from '../../database/client';
import { NotFoundError } from '../../utils/app-error';
import { UpdateOrganizationInput } from './organization.dto';

export class OrganizationService {
  async getProfile() {
    const org = await prisma.organization.findFirst();
    if (!org) {
      throw new NotFoundError('Organisasi belum dikonfigurasi. Silakan jalankan bootstrap.');
    }
    return org;
  }

  async updateProfile(input: UpdateOrganizationInput) {
    const org = await prisma.organization.findFirst();
    if (!org) {
      throw new NotFoundError('Organisasi belum dikonfigurasi.');
    }

    const updated = await prisma.organization.update({
      where: { id: org.id },
      data: {
        name: input.name,
        code: input.code,
        address: input.address,
        phone: input.phone,
        email: input.email,
        timezone: input.timezone,
      },
    });

    return updated;
  }
}

export const organizationService = new OrganizationService();
