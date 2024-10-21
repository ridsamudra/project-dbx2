# app_revenue_realtime/views_revenue_realtime.py

import json
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import JSONParser
from django.db.models import Sum, Max
from .models import RevenueRealtime
from .serializers import RevenueRealtimeSerializer
from datetime import datetime, timedelta
from app_users.utils import get_session_data_from_body, fetch_user_locations, is_admin_user

@method_decorator(csrf_exempt, name='dispatch')
class RevenueRealtimeView(APIView):
    parser_classes = [JSONParser]

    def get(self, request, *args, **kwargs):
        try:
            # Langkah 1: Mendapatkan session data
            # Coba ambil dari body, jika gagal coba dari query params, lalu dari headers
            session_data_result = get_session_data_from_body(request)
            if isinstance(session_data_result, dict) and 'error' in session_data_result:
                session_data_str = request.GET.get('session_data') or request.headers.get('X-Session-Data')
                if session_data_str:
                    try:
                        session_data = json.loads(session_data_str)
                    except json.JSONDecodeError:
                        return Response({"status": "error", "message": "Invalid session data format"}, status=400)
                else:
                    return Response({"status": "error", "message": session_data_result['error']}, status=400)
            else:
                session_data = session_data_result

            is_admin = is_admin_user(session_data)
            if isinstance(is_admin, dict) and 'error' in is_admin:
                return Response({"status": "error", "message": is_admin['error']}, status=400)

            locations = fetch_user_locations(session_data)
            if isinstance(locations, dict) and 'error' in locations:
                return Response({"status": "error", "message": locations['error']}, status=400)

            if request.path.endswith('bylocations'):
                return self.view_by_locations(locations)
            else:
                return self.view_all(locations)

        except Exception as e:
            return Response({"status": "error", "message": f"Terjadi kesalahan: {str(e)}"}, status=500)

    def view_all(self, locations):
        try:
            latest_waktu = RevenueRealtime.objects.filter(id_lokasi__in=locations).aggregate(Max('waktu'))['waktu__max']
            if not latest_waktu:
                return Response({"detail": "No data available"}, status=404)

            kendaraan_data = RevenueRealtime.objects.filter(
                id_lokasi__in=locations,
                tanggal=latest_waktu.date(),
                waktu__lte=latest_waktu
            ).values('kendaraan').annotate(
                jumlah_transaksi=Sum('qty'),
                jumlah_pendapatan=Sum('jumlah')
            )

            data_list = []
            for kendaraan in kendaraan_data:
                data = {
                    "waktu": latest_waktu,
                    "jenis_kendaraan": kendaraan['kendaraan'],
                    "jumlah_transaksi": kendaraan['jumlah_transaksi'],
                    "jumlah_pendapatan": int(kendaraan['jumlah_pendapatan']) 
                }
                serializer = RevenueRealtimeSerializer(data)
                data_list.append(serializer.data)

            return Response(data_list)

        except Exception as e:
            return Response({"status": "error", "message": f"Error in view_all: {str(e)}"}, status=500)

    def view_by_locations(self, locations):
        try:
            location_data = {}

            # Ambil waktu terbaru dari data di setiap lokasi
            latest_waktu = RevenueRealtime.objects.filter(id_lokasi__in=locations).aggregate(Max('waktu'))['waktu__max']
            if not latest_waktu:
                return Response({"detail": "No data available"}, status=404)

            # Query untuk mendapatkan data berdasarkan lokasi
            revenue_data = RevenueRealtime.objects.filter(
                id_lokasi__in=locations,
                tanggal=latest_waktu.date(),
                waktu__lte=latest_waktu
            ).values('id_lokasi__site', 'kendaraan').annotate(
                jumlah_transaksi=Sum('qty'),
                jumlah_pendapatan=Sum('jumlah')
            )

            # Format data untuk setiap lokasi
            for location in locations:
                site_name = location.site  # Nama lokasi (site)
                location_data[site_name] = []

                # Ambil data kendaraan untuk setiap lokasi
                kendaraan_data = [item for item in revenue_data if item['id_lokasi__site'] == site_name]

                # Loop data kendaraan
                for kendaraan in kendaraan_data:
                    data = {
                        "waktu": latest_waktu,
                        "jenis_kendaraan": kendaraan['kendaraan'],
                        "jumlah_transaksi": kendaraan['jumlah_transaksi'],
                        "jumlah_pendapatan": int(kendaraan['jumlah_pendapatan'])  # Cast ke int
                    }
                    
                    location_data[site_name].append(data)

            return Response(location_data)

        except Exception as e:
            return Response({"status": "error", "message": f"Error in view_by_locations: {str(e)}"}, status=500)
