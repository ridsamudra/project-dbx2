# app_revenue_realtime/views_revenue_by_locations.py

import json
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import JSONParser
from django.db.models import Sum, Max
from datetime import datetime, date
from app_users.utils import get_session_data_from_body, fetch_user_locations, is_admin_user
from app_revenue_realtime.models import RevenueRealtime

@method_decorator(csrf_exempt, name='dispatch')
class RevenueByLocationsView(APIView):
    parser_classes = [JSONParser]

    def get(self, request, *args, **kwargs):
        try:
            # Step 1: Get session data from body or fallback to query params/headers
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

            # Check if the user is an admin
            is_admin = is_admin_user(session_data)
            if isinstance(is_admin, dict) and 'error' in is_admin:
                return Response({"status": "error", "message": is_admin['error']}, status=400)

            # Fetch user locations based on session data
            locations = fetch_user_locations(session_data)
            if isinstance(locations, dict) and 'error' in locations:
                return Response({"status": "error", "message": locations['error']}, status=400)

            # Check if it's view_all or view_by_locations endpoint
            if request.path.endswith('bylocations'):
                return self.view_by_locations(locations)
            else:
                return self.view_all(locations)

        except Exception as e:
            return Response({"status": "error", "message": f"Terjadi kesalahan: {str(e)}"}, status=500)

    def get_location_data(self, site_name):
        today = date.today()
        
        # Get the latest data for this location
        latest_data = RevenueRealtime.objects.filter(
            id_lokasi__site=site_name
        ).order_by('-tanggal', '-waktu').first()

        if latest_data:
            if latest_data.tanggal == today:
                # If there's data for today, use it
                revenue_data = RevenueRealtime.objects.filter(
                    id_lokasi__site=site_name,
                    tanggal=latest_data.tanggal,
                    waktu=latest_data.waktu
                ).aggregate(
                    total_transaksi=Sum('qty'),
                    total_pendapatan=Sum('jumlah')
                )
            else:
                # If no data for today, get the last available data
                revenue_data = RevenueRealtime.objects.filter(
                    id_lokasi__site=site_name,
                    tanggal=latest_data.tanggal
                ).aggregate(
                    total_transaksi=Sum('qty'),
                    total_pendapatan=Sum('jumlah')
                )

            return {
                "waktu": latest_data.waktu,
                "tanggal": latest_data.tanggal,
                "id_lokasi": site_name,
                "total_transaksi": revenue_data['total_transaksi'] or 0,
                "total_pendapatan": int(revenue_data['total_pendapatan'] or 0)
            }
        
        return None

    def view_all(self, locations):
        try:
            data_list = []
            for location in locations:
                site_name = location.site
                location_data = self.get_location_data(site_name)
                
                if location_data:
                    data_list.append(location_data)

            return Response(data_list)

        except Exception as e:
            return Response({"status": "error", "message": f"Error in view_all: {str(e)}"}, status=500)

    def view_by_locations(self, locations):
        try:
            location_data = {}
            
            for location in locations:
                site_name = location.site
                data = self.get_location_data(site_name)
                
                if data:
                    location_data[site_name] = [data]
                else:
                    location_data[site_name] = []

            return Response(location_data)

        except Exception as e:
            return Response({"status": "error", "message": f"Error in view_by_locations: {str(e)}"}, status=500)